@tool
extends EditorInspectorPlugin

const _MINUTES_PER_DAY := 24 * 60
const _ROUTES_DIR := "res://data/routes"

var _editor_interface: EditorInterface = null
var _undo: EditorUndoRedoManager = null

func init(editor_interface: EditorInterface, undo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo = undo

func _can_handle(object: Object) -> bool:
	return object is NpcSchedule

func _parse_begin(object: Object) -> void:
	var schedule := object as NpcSchedule
	var ui := _ScheduleInspectorUI.new()
	ui.init(schedule, _undo)
	add_custom_control(ui)


class _ScheduleInspectorUI:
	extends VBoxContainer

	var _schedule: NpcSchedule
	var _undo: EditorUndoRedoManager

	var _steps_vbox: VBoxContainer

	func init(schedule: NpcSchedule, undo: EditorUndoRedoManager) -> void:
		_schedule = schedule
		_undo = undo

		var header := HBoxContainer.new()
		var title := Label.new()
		title.text = "NPC Schedule"
		title.add_theme_font_size_override("font_size", 16)
		header.add_child(title)

		var btn_add := Button.new()
		btn_add.text = "Add step"
		btn_add.pressed.connect(_on_add_step)
		header.add_child(btn_add)

		var btn_sort := Button.new()
		btn_sort.text = "Sort"
		btn_sort.pressed.connect(_on_sort_steps)
		header.add_child(btn_sort)

		var btn_chain := Button.new()
		btn_chain.text = "Auto-chain"
		btn_chain.tooltip_text = "Set each step start to previous end (in order)."
		btn_chain.pressed.connect(_on_auto_chain)
		header.add_child(btn_chain)

		add_child(header)

		var hint := Label.new()
		hint.text = "Edit steps in HH:MM. Keep TRAVEL steps short. Use the Tools menu to bake level routes into RouteResources."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(hint)

		_steps_vbox = VBoxContainer.new()
		add_child(_steps_vbox)

		_rebuild()

	func _rebuild() -> void:
		for c in _steps_vbox.get_children():
			c.queue_free()

		if _schedule == null:
			return

		for i in range(_schedule.steps.size()):
			var step := _schedule.steps[i]
			if step == null:
				continue
			var row := _make_step_row(i, step)
			# If a step is a placeholder instance and something errors while building the row,
			# don't crash the editor by adding a null child.
			if row != null:
				_steps_vbox.add_child(row)

	func _make_step_row(index: int, step: NpcScheduleStep) -> Control:
		var row := VBoxContainer.new()

		var top := HBoxContainer.new()
		row.add_child(top)

		var lbl := Label.new()
		lbl.text = "#%d" % index
		top.add_child(lbl)

		var kind := OptionButton.new()
		kind.add_item("HOLD", int(NpcScheduleStep.Kind.HOLD))
		kind.add_item("ROUTE", int(NpcScheduleStep.Kind.ROUTE))
		kind.add_item("TRAVEL", int(NpcScheduleStep.Kind.TRAVEL))
		kind.selected = kind.get_item_index(int(step.kind))
		kind.item_selected.connect(func(_idx: int) -> void:
			_set_step_prop(step, "kind", kind.get_selected_id())
		)
		top.add_child(kind)

		var hour := SpinBox.new()
		hour.min_value = 0
		hour.max_value = 23
		hour.step = 1
		hour.value = int(step.start_minute_of_day / 60)
		top.add_child(Label.new())
		top.get_child(top.get_child_count() - 1).text = "H"
		top.add_child(hour)

		var minute := SpinBox.new()
		minute.min_value = 0
		minute.max_value = 59
		minute.step = 1
		minute.value = int(step.start_minute_of_day % 60)
		top.add_child(Label.new())
		top.get_child(top.get_child_count() - 1).text = "M"
		top.add_child(minute)

		# Connect after both controls exist (avoids capture-before-declare).
		hour.value_changed.connect(func(_v: float) -> void:
			_set_start_hm(step, int(hour.value), int(minute.value))
		)
		minute.value_changed.connect(func(_v: float) -> void:
			_set_start_hm(step, int(hour.value), int(minute.value))
		)

		var dur := SpinBox.new()
		dur.min_value = 1
		dur.max_value = _MINUTES_PER_DAY
		dur.step = 1
		dur.value = int(step.duration_minutes)
		dur.value_changed.connect(func(v: float) -> void:
			_set_step_prop(step, "duration_minutes", int(v))
		)
		top.add_child(Label.new())
		top.get_child(top.get_child_count() - 1).text = "Dur(min)"
		top.add_child(dur)

		var btn_del := Button.new()
		btn_del.text = "Remove"
		btn_del.pressed.connect(func() -> void:
			_remove_step(index)
		)
		top.add_child(btn_del)

		var details := HBoxContainer.new()
		row.add_child(details)

		match int(step.kind):
			int(NpcScheduleStep.Kind.ROUTE):
				# ROUTE fields
				var level := OptionButton.new()
				for k in Enums.Levels.keys():
					level.add_item(k, int(Enums.Levels[k]))
				level.selected = level.get_item_index(int(step.level_id))
				level.item_selected.connect(func(_idx: int) -> void:
					_set_step_prop(step, "level_id", level.get_selected_id())
				)
				details.add_child(Label.new())
				details.get_child(details.get_child_count() - 1).text = "Level"
				details.add_child(level)

				# RouteResource (preferred)
				var route_res_row := HBoxContainer.new()
				var route_res_label := Label.new()
				route_res_label.text = "RouteRes"
				details.add_child(route_res_label)
				details.add_child(route_res_row)

				var route_res_path := LineEdit.new()
				route_res_path.editable = false
				route_res_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				route_res_path.text = (
					step.route_res.resource_path if step.route_res != null else ""
				)
				route_res_row.add_child(route_res_path)

				var fd_route := EditorFileDialog.new()
				fd_route.access = EditorFileDialog.ACCESS_RESOURCES
				fd_route.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
				fd_route.current_dir = _ROUTES_DIR
				fd_route.filters = PackedStringArray(["*.tres ; RouteResource"])
				row.add_child(fd_route)

				var btn_pick_route := Button.new()
				btn_pick_route.text = "Pick…"
				btn_pick_route.pressed.connect(func() -> void:
					fd_route.popup_centered_ratio(0.6)
				)
				route_res_row.add_child(btn_pick_route)

				var btn_use_baked := Button.new()
				btn_use_baked.text = "Set level from route"
				btn_use_baked.tooltip_text = "Copies level_id from the selected RouteResource."
				btn_use_baked.pressed.connect(func() -> void:
					if step.route_res != null:
						_set_step_prop(step, "level_id", int((step.route_res as RouteResource).level_id))
				)
				route_res_row.add_child(btn_use_baked)
				var btn_clear_route := Button.new()
				btn_clear_route.text = "Clear"
				btn_clear_route.pressed.connect(func() -> void:
					_set_step_prop(step, "route_res", null)
				)
				route_res_row.add_child(btn_clear_route)

				fd_route.file_selected.connect(func(path: String) -> void:
					var res := load(path)
					if res is RouteResource:
						_set_step_prop(step, "route_res", res)
				)

				var loop_cb := CheckBox.new()
				loop_cb.text = "Loop"
				loop_cb.button_pressed = bool(step.loop_route)
				loop_cb.toggled.connect(func(v: bool) -> void:
					_set_step_prop(step, "loop_route", v)
				)
				details.add_child(loop_cb)
			int(NpcScheduleStep.Kind.TRAVEL):
				# TRAVEL fields
				var target_level := OptionButton.new()
				for k in Enums.Levels.keys():
					target_level.add_item(k, int(Enums.Levels[k]))
				target_level.selected = target_level.get_item_index(int(step.target_level_id))
				target_level.item_selected.connect(func(_idx: int) -> void:
					_set_step_prop(step, "target_level_id", target_level.get_selected_id())
				)
				details.add_child(Label.new())
				details.get_child(details.get_child_count() - 1).text = "To level"
				details.add_child(target_level)

				var target_spawn := OptionButton.new()
				for k in Enums.SpawnId.keys():
					target_spawn.add_item(k, int(Enums.SpawnId[k]))
				target_spawn.selected = target_spawn.get_item_index(int(step.target_spawn_id))
				target_spawn.item_selected.connect(func(_idx: int) -> void:
					_set_step_prop(step, "target_spawn_id", target_spawn.get_selected_id())
				)
				details.add_child(Label.new())
				details.get_child(details.get_child_count() - 1).text = "Spawn"
				details.add_child(target_spawn)

				# Exit RouteResource (optional)
				var exit_res_row := HBoxContainer.new()
				var exit_res_label := Label.new()
				exit_res_label.text = "ExitRes"
				details.add_child(exit_res_label)
				details.add_child(exit_res_row)

				var exit_res_path := LineEdit.new()
				exit_res_path.editable = false
				exit_res_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				exit_res_path.text = (
					step.exit_route_res.resource_path if step.exit_route_res != null else ""
				)
				exit_res_row.add_child(exit_res_path)

				var fd_exit := EditorFileDialog.new()
				fd_exit.access = EditorFileDialog.ACCESS_RESOURCES
				fd_exit.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
				fd_exit.current_dir = _ROUTES_DIR
				fd_exit.filters = PackedStringArray(["*.tres ; RouteResource"])
				row.add_child(fd_exit)

				var btn_pick_exit := Button.new()
				btn_pick_exit.text = "Pick…"
				btn_pick_exit.pressed.connect(func() -> void:
					fd_exit.popup_centered_ratio(0.6)
				)
				exit_res_row.add_child(btn_pick_exit)

				var btn_clear_exit := Button.new()
				btn_clear_exit.text = "Clear"
				btn_clear_exit.pressed.connect(func() -> void:
					_set_step_prop(step, "exit_route_res", null)
				)
				exit_res_row.add_child(btn_clear_exit)

				fd_exit.file_selected.connect(func(path: String) -> void:
					var res := load(path)
					if res is RouteResource:
						_set_step_prop(step, "exit_route_res", res)
				)
			_:
				# HOLD: no extra fields (for now).
				pass

		# Light validation label
		var warn := Label.new()
		warn.modulate = Color(1.0, 0.7, 0.2)
		# NOTE: `NpcScheduleStep` is not `@tool`, so in the editor it can be a placeholder instance.
		# Calling methods on placeholder instances errors; validate using exported properties only.
		warn.text = "" if _is_step_valid_in_editor(step) else "⚠ invalid step"
		row.add_child(warn)

		return row

	func _is_step_valid_in_editor(step: NpcScheduleStep) -> bool:
		if step == null:
			return false
		if int(step.duration_minutes) <= 0:
			return false
		match int(step.kind):
			int(NpcScheduleStep.Kind.ROUTE):
				return (
					int(step.level_id) != int(Enums.Levels.NONE)
					and step.route_res != null
				)
			int(NpcScheduleStep.Kind.TRAVEL):
				return int(step.target_level_id) != int(Enums.Levels.NONE)
			_:
				# HOLD is always valid; level_id is optional.
				return true

	func _level_key(level_id: Enums.Levels) -> String:
		for k in Enums.Levels.keys():
			if int(Enums.Levels[k]) == int(level_id):
				return String(k).to_lower()
		return "level_%d" % int(level_id)

	func _set_start_hm(step: NpcScheduleStep, h: int, m: int) -> void:
		var minute_of_day := clampi(h * 60 + m, 0, _MINUTES_PER_DAY - 1)
		_set_step_prop(step, "start_minute_of_day", minute_of_day)

	func _set_step_prop(step: NpcScheduleStep, prop: String, value: Variant) -> void:
		if _undo == null or _schedule == null:
			step.set(prop, value)
			_rebuild()
			return
		_undo.create_action("Edit schedule step")
		_undo.add_do_property(step, prop, value)
		_undo.add_undo_property(step, prop, step.get(prop))
		_undo.commit_action()
		_rebuild()

	func _on_add_step() -> void:
		if _schedule == null:
			return
		var step := NpcScheduleStep.new()
		# Default: start at 00:00, 30min HOLD.
		step.start_minute_of_day = 0
		step.duration_minutes = 30
		step.kind = NpcScheduleStep.Kind.HOLD
		if _undo != null:
			_undo.create_action("Add schedule step")
			var old_steps := _schedule.steps.duplicate()
			var new_steps := old_steps.duplicate()
			new_steps.append(step)
			_undo.add_do_property(_schedule, "steps", new_steps)
			_undo.add_undo_property(_schedule, "steps", old_steps)
			_undo.commit_action()
		else:
			_schedule.steps.append(step)
		_rebuild()

	func _remove_step(index: int) -> void:
		if _schedule == null:
			return
		var old_steps := _schedule.steps.duplicate()
		if index < 0 or index >= old_steps.size():
			return
		var new_steps := old_steps.duplicate()
		new_steps.remove_at(index)
		if _undo != null:
			_undo.create_action("Remove schedule step")
			_undo.add_do_property(_schedule, "steps", new_steps)
			_undo.add_undo_property(_schedule, "steps", old_steps)
			_undo.commit_action()
		else:
			_schedule.steps = new_steps
		_rebuild()

	func _on_sort_steps() -> void:
		if _schedule == null:
			return
		var old_steps := _schedule.steps.duplicate()
		var new_steps := old_steps.duplicate()
		new_steps.sort_custom(func(a: NpcScheduleStep, b: NpcScheduleStep) -> bool:
			if a == null:
				return true
			if b == null:
				return false
			return a.start_minute_of_day < b.start_minute_of_day
		)
		if _undo != null:
			_undo.create_action("Sort schedule steps")
			_undo.add_do_property(_schedule, "steps", new_steps)
			_undo.add_undo_property(_schedule, "steps", old_steps)
			_undo.commit_action()
		else:
			_schedule.steps = new_steps
		_rebuild()

	func _on_auto_chain() -> void:
		if _schedule == null:
			return
		var old_steps := _schedule.steps.duplicate()
		var new_steps := old_steps.duplicate()
		var t := 0
		for s in new_steps:
			if s == null:
				continue
			s.start_minute_of_day = clampi(t, 0, _MINUTES_PER_DAY - 1)
			t += max(1, s.duration_minutes)
		if _undo != null:
			_undo.create_action("Auto-chain schedule steps")
			_undo.add_do_property(_schedule, "steps", new_steps)
			_undo.add_undo_property(_schedule, "steps", old_steps)
			_undo.commit_action()
		else:
			_schedule.steps = new_steps
		_rebuild()

