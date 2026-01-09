@tool
extends VBoxContainer

const _MINUTES_PER_DAY := 24 * 60
const _SCHEDULES_DIR := "res://game/entities/npc/schedules"
const _NPC_CONFIGS_DIR := "res://game/entities/npc/configs"
const _ROUTES_DIR := "res://game/data/routes"
const _SPAWNPOINTS_DIR := "res://game/data/spawn_points"

var _editor_interface: EditorInterface = null
var _undo: EditorUndoRedoManager = null

var _schedule: NpcSchedule = null
var _npc_config: NpcConfig = null

var _schedule_path: LineEdit = null
var _npc_config_path: LineEdit = null
var _steps_vbox: VBoxContainer = null

var _fd_pick_cfg: EditorFileDialog = null
var _fd_pick_schedule: EditorFileDialog = null
var _fd_pick_route: EditorFileDialog = null
var _fd_pick_spawn: EditorFileDialog = null
var _fd_save_spawn: EditorFileDialog = null
var _fd_save_route: EditorFileDialog = null

var _pending_route_step: NpcScheduleStep = null
var _pending_spawn_target_step: NpcScheduleStep = null
var _pending_spawn_target_point: NpcIdleAroundPoint = null


func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func set_undo_redo(undo: EditorUndoRedoManager) -> void:
	_undo = undo


func edit_resource(object: Object) -> void:
	if object is NpcConfig:
		_set_npc_config(object as NpcConfig)
		return
	if object is NpcSchedule:
		_set_schedule(object as NpcSchedule)
		return


func _ready() -> void:
	_build_ui()
	_rebuild()


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "Schedule Editor"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var pick_cfg_row := HBoxContainer.new()
	add_child(pick_cfg_row)

	pick_cfg_row.add_child(_mk_label("NPC Config"))
	_npc_config_path = LineEdit.new()
	_npc_config_path.editable = false
	_npc_config_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_config_path.size_flags_stretch_ratio = 4.0
	pick_cfg_row.add_child(_npc_config_path)

	_fd_pick_cfg = EditorFileDialog.new()
	_fd_pick_cfg.access = EditorFileDialog.ACCESS_RESOURCES
	_fd_pick_cfg.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_fd_pick_cfg.current_dir = _NPC_CONFIGS_DIR
	_fd_pick_cfg.filters = PackedStringArray(["*.tres ; NpcConfig"])
	add_child(_fd_pick_cfg)

	var btn_pick_cfg := Button.new()
	btn_pick_cfg.text = "Pick…"
	btn_pick_cfg.pressed.connect(func() -> void:
		if _fd_pick_cfg != null:
			_fd_pick_cfg.popup_centered_ratio(0.6)
	)
	pick_cfg_row.add_child(btn_pick_cfg)

	var btn_clear_cfg := Button.new()
	btn_clear_cfg.text = "Clear"
	btn_clear_cfg.pressed.connect(func() -> void:
		_set_npc_config(null)
	)
	pick_cfg_row.add_child(btn_clear_cfg)

	var btn_open_cfg := Button.new()
	btn_open_cfg.text = "Open"
	btn_open_cfg.pressed.connect(func() -> void:
		if _editor_interface != null and _npc_config != null:
			_editor_interface.edit_resource(_npc_config)
	)
	pick_cfg_row.add_child(btn_open_cfg)

	_fd_pick_cfg.file_selected.connect(func(path: String) -> void:
		var res := load(path)
		if res is NpcConfig:
			_set_npc_config(res)
	)

	var pick_schedule_row := HBoxContainer.new()
	add_child(pick_schedule_row)

	pick_schedule_row.add_child(_mk_label("Schedule"))
	_schedule_path = LineEdit.new()
	_schedule_path.editable = false
	_schedule_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_schedule_path.size_flags_stretch_ratio = 4.0
	pick_schedule_row.add_child(_schedule_path)

	_fd_pick_schedule = EditorFileDialog.new()
	_fd_pick_schedule.access = EditorFileDialog.ACCESS_RESOURCES
	_fd_pick_schedule.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_fd_pick_schedule.current_dir = _SCHEDULES_DIR
	_fd_pick_schedule.filters = PackedStringArray(["*.tres ; NpcSchedule"])
	add_child(_fd_pick_schedule)

	var btn_pick_schedule := Button.new()
	btn_pick_schedule.text = "Pick…"
	btn_pick_schedule.pressed.connect(func() -> void:
		if _fd_pick_schedule != null:
			_fd_pick_schedule.popup_centered_ratio(0.6)
	)
	pick_schedule_row.add_child(btn_pick_schedule)

	var btn_clear_schedule := Button.new()
	btn_clear_schedule.text = "Clear"
	btn_clear_schedule.pressed.connect(func() -> void:
		_set_schedule(null)
	)
	pick_schedule_row.add_child(btn_clear_schedule)

	var btn_open_schedule := Button.new()
	btn_open_schedule.text = "Open"
	btn_open_schedule.pressed.connect(func() -> void:
		if _editor_interface != null and _schedule != null:
			_editor_interface.edit_resource(_schedule)
	)
	pick_schedule_row.add_child(btn_open_schedule)

	_fd_pick_schedule.file_selected.connect(func(path: String) -> void:
		var res := load(path)
		if res is NpcSchedule:
			_set_schedule(res)
	)

	var tools_row := HBoxContainer.new()
	add_child(tools_row)

	var btn_add := Button.new()
	btn_add.text = "Add step"
	btn_add.pressed.connect(_on_add_step)
	tools_row.add_child(btn_add)

	var btn_sort := Button.new()
	btn_sort.text = "Sort"
	btn_sort.pressed.connect(_on_sort_steps)
	tools_row.add_child(btn_sort)

	var btn_chain := Button.new()
	btn_chain.text = "Auto-chain"
	btn_chain.tooltip_text = "Set each step start to previous end (in order)."
	btn_chain.pressed.connect(_on_auto_chain)
	tools_row.add_child(btn_chain)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_row.add_child(spacer)

	var btn_create_sp := Button.new()
	btn_create_sp.text = "New SpawnPoint…"
	btn_create_sp.pressed.connect(_on_create_spawn_point)
	tools_row.add_child(btn_create_sp)

	var btn_create_route := Button.new()
	btn_create_route.text = "New Route…"
	btn_create_route.pressed.connect(_on_create_route)
	tools_row.add_child(btn_create_route)

	_steps_vbox = VBoxContainer.new()
	_steps_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_steps_vbox)

	# Shared pick dialogs to avoid per-row dialog churn (stability).
	_fd_pick_route = EditorFileDialog.new()
	_fd_pick_route.access = EditorFileDialog.ACCESS_RESOURCES
	_fd_pick_route.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_fd_pick_route.current_dir = _ROUTES_DIR
	_fd_pick_route.filters = PackedStringArray(["*.tres ; RouteResource"])
	add_child(_fd_pick_route)
	_fd_pick_route.file_selected.connect(_on_pick_route_selected)

	_fd_pick_spawn = EditorFileDialog.new()
	_fd_pick_spawn.access = EditorFileDialog.ACCESS_RESOURCES
	_fd_pick_spawn.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_fd_pick_spawn.current_dir = _SPAWNPOINTS_DIR
	_fd_pick_spawn.filters = PackedStringArray(["*.tres ; SpawnPointData"])
	add_child(_fd_pick_spawn)
	_fd_pick_spawn.file_selected.connect(_on_pick_spawn_selected)

	# Shared save dialogs.
	_fd_save_spawn = EditorFileDialog.new()
	_fd_save_spawn.access = EditorFileDialog.ACCESS_RESOURCES
	_fd_save_spawn.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_fd_save_spawn.current_dir = _SPAWNPOINTS_DIR
	_fd_save_spawn.current_file = "new_spawn_point.tres"
	_fd_save_spawn.filters = PackedStringArray(["*.tres ; SpawnPointData"])
	add_child(_fd_save_spawn)
	_fd_save_spawn.file_selected.connect(_on_save_spawn_selected)

	_fd_save_route = EditorFileDialog.new()
	_fd_save_route.access = EditorFileDialog.ACCESS_RESOURCES
	_fd_save_route.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_fd_save_route.current_dir = _ROUTES_DIR
	_fd_save_route.current_file = "new_route.tres"
	_fd_save_route.filters = PackedStringArray(["*.tres ; RouteResource"])
	add_child(_fd_save_route)
	_fd_save_route.file_selected.connect(_on_save_route_selected)


func _rebuild() -> void:
	if _npc_config_path != null:
		var p := _npc_config.resource_path if _npc_config != null else ""
		_npc_config_path.text = _short_path_last_dir_file(p)
		_npc_config_path.tooltip_text = p
	if _schedule_path != null:
		var p2 := _schedule.resource_path if _schedule != null else ""
		_schedule_path.text = _short_path_last_dir_file(p2)
		_schedule_path.tooltip_text = p2

	if _steps_vbox == null:
		return
	for c in _steps_vbox.get_children():
		c.queue_free()

	if _schedule == null:
		var hint := Label.new()
		hint.text = "Pick an NPC config or a schedule resource to edit."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_steps_vbox.add_child(hint)
		return

	for i in range(_schedule.steps.size()):
		var step := _schedule.steps[i]
		if step == null:
			continue
		_steps_vbox.add_child(_make_step_row(i, step))


func _set_npc_config(cfg: NpcConfig) -> void:
	_npc_config = cfg
	if _npc_config != null and _npc_config.schedule != null:
		_set_schedule(_npc_config.schedule)
	else:
		_rebuild()


func _set_schedule(schedule: NpcSchedule) -> void:
	_schedule = schedule
	_rebuild()


func _make_step_row(index: int, step: NpcScheduleStep) -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	outer.add_child(top)

	top.add_child(_mk_label("#%d" % index))

	var kind := OptionButton.new()
	kind.add_item("HOLD", int(NpcScheduleStep.Kind.HOLD))
	kind.add_item("ROUTE", int(NpcScheduleStep.Kind.ROUTE))
	kind.add_item("IDLE_AROUND", int(NpcScheduleStep.Kind.IDLE_AROUND))
	var kind_idx := kind.get_item_index(int(step.kind))
	if kind_idx >= 0:
		kind.selected = kind_idx
	kind.item_selected.connect(func(_idx: int) -> void:
		_set_step_prop(step, "kind", kind.get_selected_id())
	)
	top.add_child(kind)

	var hour := SpinBox.new()
	hour.min_value = 0
	hour.max_value = 23
	hour.step = 1
	hour.value = int(step.start_minute_of_day / 60)
	top.add_child(_mk_label("H"))
	top.add_child(hour)

	var minute := SpinBox.new()
	minute.min_value = 0
	minute.max_value = 59
	minute.step = 1
	minute.value = int(step.start_minute_of_day % 60)
	top.add_child(_mk_label("M"))
	top.add_child(minute)

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
	top.add_child(_mk_label("Dur"))
	top.add_child(dur)

	var facing := OptionButton.new()
	facing.add_item("Down", 0)
	facing.add_item("Up", 1)
	facing.add_item("Left", 2)
	facing.add_item("Right", 3)

	var current_facing := step.facing_dir
	if current_facing == Vector2.UP: facing.selected = 1
	elif current_facing == Vector2.LEFT: facing.selected = 2
	elif current_facing == Vector2.RIGHT: facing.selected = 3
	else: facing.selected = 0

	facing.item_selected.connect(func(idx: int) -> void:
		var v := Vector2.DOWN
		match idx:
			1: v = Vector2.UP
			2: v = Vector2.LEFT
			3: v = Vector2.RIGHT
		_set_step_prop(step, "facing_dir", v)
	)
	top.add_child(_mk_label("Face"))
	top.add_child(facing)

	var btn_del := Button.new()
	btn_del.text = "Remove"
	btn_del.pressed.connect(func() -> void:
		_remove_step(index)
	)
	top.add_child(btn_del)

	var details := VBoxContainer.new()
	outer.add_child(details)

	match int(step.kind):
		int(NpcScheduleStep.Kind.ROUTE):
			details.add_child(_make_route_ui(step))
		int(NpcScheduleStep.Kind.IDLE_AROUND):
			details.add_child(_make_idle_around_ui(step))
		_:
			details.add_child(_make_hold_ui(step))

	var warn := Label.new()
	warn.modulate = Color(1.0, 0.7, 0.2)
	warn.text = "" if _is_step_valid(step) else "⚠ invalid step"
	outer.add_child(warn)

	return outer


func _make_route_ui(step: NpcScheduleStep) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_mk_label("Route"))

	var path := LineEdit.new()
	path.editable = false
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path.size_flags_stretch_ratio = 4.0
	var p := step.route_res.resource_path if step.route_res != null else ""
	path.text = _short_path_last_dir_file(p)
	path.tooltip_text = p
	row.add_child(path)

	var btn_pick := Button.new()
	btn_pick.text = "Pick…"
	btn_pick.pressed.connect(func() -> void:
		_pending_route_step = step
		if _fd_pick_route != null:
			_fd_pick_route.popup_centered_ratio(0.6)
	)
	row.add_child(btn_pick)

	var btn_clear := Button.new()
	btn_clear.text = "Clear"
	btn_clear.pressed.connect(func() -> void:
		_set_step_prop(step, "route_res", null)
	)
	row.add_child(btn_clear)

	var btn_open := Button.new()
	btn_open.text = "Open"
	btn_open.tooltip_text = "Open this route resource in the inspector."
	btn_open.pressed.connect(func() -> void:
		if _editor_interface != null and step.route_res != null:
			_editor_interface.edit_resource(step.route_res)
	)
	row.add_child(btn_open)

	var loop_cb := CheckBox.new()
	loop_cb.text = "Loop"
	loop_cb.button_pressed = bool(step.loop_route)
	loop_cb.toggled.connect(func(v: bool) -> void:
		_set_step_prop(step, "loop_route", v)
	)
	row.add_child(loop_cb)

	var chain_cb := CheckBox.new()
	chain_cb.text = "Chain next"
	chain_cb.tooltip_text = "When finished (and Loop is OFF), start the next ROUTE step."
	chain_cb.button_pressed = bool(step.chain_next_route)
	chain_cb.toggled.connect(func(v: bool) -> void:
		_set_step_prop(step, "chain_next_route", v)
	)
	row.add_child(chain_cb)

	return row


func _make_hold_ui(step: NpcScheduleStep) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_mk_label("SpawnPoint"))

	var path := LineEdit.new()
	path.editable = false
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path.size_flags_stretch_ratio = 4.0
	var p := step.hold_spawn_point.resource_path if step.hold_spawn_point != null else ""
	path.text = _short_path_last_dir_file(p)
	path.tooltip_text = p
	row.add_child(path)

	var btn_pick := Button.new()
	btn_pick.text = "Pick…"
	btn_pick.pressed.connect(func() -> void:
		_pending_spawn_target_step = step
		_pending_spawn_target_point = null
		if _fd_pick_spawn != null:
			_fd_pick_spawn.popup_centered_ratio(0.6)
	)
	row.add_child(btn_pick)

	var btn_clear := Button.new()
	btn_clear.text = "Clear"
	btn_clear.pressed.connect(func() -> void:
		_set_step_prop(step, "hold_spawn_point", null)
	)
	row.add_child(btn_clear)

	var btn_open := Button.new()
	btn_open.text = "Open"
	btn_open.tooltip_text = "Open this spawn point resource in the inspector."
	btn_open.pressed.connect(func() -> void:
		if _editor_interface != null and step.hold_spawn_point != null:
			_editor_interface.edit_resource(step.hold_spawn_point)
	)
	row.add_child(btn_open)

	return row


func _make_idle_around_ui(step: NpcScheduleStep) -> Control:
	var root := VBoxContainer.new()

	var header := HBoxContainer.new()
	root.add_child(header)

	var random_cb := CheckBox.new()
	random_cb.text = "Random"
	random_cb.button_pressed = bool(step.idle_random)
	random_cb.toggled.connect(func(v: bool) -> void:
		_set_step_prop(step, "idle_random", v)
	)
	header.add_child(random_cb)

	var btn_add := Button.new()
	btn_add.text = "Add point"
	btn_add.pressed.connect(func() -> void:
		_add_idle_point(step)
	)
	header.add_child(btn_add)

	var warn := Label.new()
	warn.modulate = Color(1.0, 0.7, 0.2)
	warn.text = _idle_points_level_warning(step)
	header.add_child(warn)

	for i in range(step.idle_points.size()):
		var p := step.idle_points[i]
		if p == null:
			continue
		root.add_child(_make_idle_point_row(step, i, p))

	return root


func _make_idle_point_row(step: NpcScheduleStep, index: int, point: NpcIdleAroundPoint) -> Control:
	var row := HBoxContainer.new()

	row.add_child(_mk_label("SP"))

	var path := LineEdit.new()
	path.editable = false
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path.size_flags_stretch_ratio = 4.0
	var p := point.spawn_point.resource_path if point.spawn_point != null else ""
	path.text = _short_path_last_dir_file(p)
	path.tooltip_text = p
	row.add_child(path)

	var btn_pick := Button.new()
	btn_pick.text = "Pick…"
	btn_pick.pressed.connect(func() -> void:
		_pending_spawn_target_step = null
		_pending_spawn_target_point = point
		if _fd_pick_spawn != null:
			_fd_pick_spawn.popup_centered_ratio(0.6)
	)
	row.add_child(btn_pick)

	var btn_open := Button.new()
	btn_open.text = "Open"
	btn_open.pressed.connect(func() -> void:
		if _editor_interface != null and point.spawn_point != null:
			_editor_interface.edit_resource(point.spawn_point)
	)
	row.add_child(btn_open)

	var hold := SpinBox.new()
	hold.min_value = 0
	hold.max_value = _MINUTES_PER_DAY
	hold.step = 1
	hold.value = int(point.hold_minutes)
	hold.value_changed.connect(func(v: float) -> void:
		_set_point_prop(point, "hold_minutes", int(v))
	)
	row.add_child(_mk_label("Hold"))
	row.add_child(hold)

	var facing := OptionButton.new()
	facing.add_item("Down", 0)
	facing.add_item("Up", 1)
	facing.add_item("Left", 2)
	facing.add_item("Right", 3)

	var current_facing := point.facing_dir
	if current_facing == Vector2.UP: facing.selected = 1
	elif current_facing == Vector2.LEFT: facing.selected = 2
	elif current_facing == Vector2.RIGHT: facing.selected = 3
	else: facing.selected = 0

	facing.item_selected.connect(func(idx: int) -> void:
		var v := Vector2.DOWN
		match idx:
			1: v = Vector2.UP
			2: v = Vector2.LEFT
			3: v = Vector2.RIGHT
		_set_point_prop(point, "facing_dir", v)
	)
	row.add_child(_mk_label("Face"))
	row.add_child(facing)

	var btn_remove := Button.new()
	btn_remove.text = "Remove"
	btn_remove.pressed.connect(func() -> void:
		_remove_idle_point(step, index)
	)
	row.add_child(btn_remove)

	return row


func _idle_points_level_warning(step: NpcScheduleStep) -> String:
	if step == null or step.idle_points.is_empty():
		return ""
	var levels: Dictionary = {}
	for p in step.idle_points:
		if p == null or not p.is_valid():
			continue
		levels[p.spawn_point.level_id] = true
	return "⚠ multiple levels" if levels.size() > 1 else ""


func _on_add_step() -> void:
	if _schedule == null:
		return
	var step := NpcScheduleStep.new()
	step.start_minute_of_day = 0
	step.duration_minutes = 30
	step.kind = NpcScheduleStep.Kind.HOLD
	_apply_schedule_steps_mutation(
		"Add schedule step",
		func(old_steps: Array[NpcScheduleStep]) -> Array[NpcScheduleStep]:
		var new_steps := old_steps.duplicate()
		new_steps.append(step)
		return new_steps
	)


func _remove_step(index: int) -> void:
	if _schedule == null:
		return
	_apply_schedule_steps_mutation(
		"Remove schedule step",
		func(old_steps: Array[NpcScheduleStep]) -> Array[NpcScheduleStep]:
		if index < 0 or index >= old_steps.size():
			return old_steps
		var new_steps := old_steps.duplicate()
		new_steps.remove_at(index)
		return new_steps
	)


func _on_sort_steps() -> void:
	if _schedule == null:
		return
	_apply_schedule_steps_mutation(
		"Sort schedule steps",
		func(old_steps: Array[NpcScheduleStep]) -> Array[NpcScheduleStep]:
		var new_steps := old_steps.duplicate()
		new_steps.sort_custom(func(a: NpcScheduleStep, b: NpcScheduleStep) -> bool:
			if a == null:
				return true
			if b == null:
				return false
			return a.start_minute_of_day < b.start_minute_of_day
		)
		return new_steps
	)


func _on_auto_chain() -> void:
	if _schedule == null:
		return
	_apply_schedule_steps_mutation(
		"Auto-chain schedule steps",
		func(old_steps: Array[NpcScheduleStep]) -> Array[NpcScheduleStep]:
		var new_steps := old_steps.duplicate()
		var t := 0
		for s in new_steps:
			if s == null:
				continue
			s.start_minute_of_day = clampi(t, 0, _MINUTES_PER_DAY - 1)
			t += max(1, s.duration_minutes)
		return new_steps
	)


func _set_start_hm(step: NpcScheduleStep, h: int, m: int) -> void:
	var minute_of_day := clampi(h * 60 + m, 0, _MINUTES_PER_DAY - 1)
	_set_step_prop(step, "start_minute_of_day", minute_of_day)


func _set_step_prop(step: NpcScheduleStep, prop: String, value: Variant) -> void:
	if step == null:
		return
	if _undo == null:
		step.set(prop, value)
		_rebuild()
		return
	_undo.create_action("Edit schedule step")
	_undo.add_do_property(step, prop, value)
	_undo.add_undo_property(step, prop, step.get(prop))
	_undo.commit_action()
	_rebuild()


func _set_point_prop(point: NpcIdleAroundPoint, prop: String, value: Variant) -> void:
	if point == null:
		return
	if _undo == null:
		point.set(prop, value)
		_rebuild()
		return
	_undo.create_action("Edit idle-around point")
	_undo.add_do_property(point, prop, value)
	_undo.add_undo_property(point, prop, point.get(prop))
	_undo.commit_action()
	_rebuild()


func _add_idle_point(step: NpcScheduleStep) -> void:
	if step == null:
		return
	var old_points := step.idle_points.duplicate()
	var new_points := old_points.duplicate()
	new_points.append(NpcIdleAroundPoint.new())
	if _undo == null:
		step.idle_points = new_points
		_rebuild()
		return
	_undo.create_action("Add idle-around point")
	_undo.add_do_property(step, "idle_points", new_points)
	_undo.add_undo_property(step, "idle_points", old_points)
	_undo.commit_action()
	_rebuild()


func _remove_idle_point(step: NpcScheduleStep, index: int) -> void:
	if step == null:
		return
	var old_points := step.idle_points.duplicate()
	if index < 0 or index >= old_points.size():
		return
	var new_points := old_points.duplicate()
	new_points.remove_at(index)
	if _undo == null:
		step.idle_points = new_points
		_rebuild()
		return
	_undo.create_action("Remove idle-around point")
	_undo.add_do_property(step, "idle_points", new_points)
	_undo.add_undo_property(step, "idle_points", old_points)
	_undo.commit_action()
	_rebuild()


func _apply_schedule_steps_mutation(action_name: String, f: Callable) -> void:
	if _schedule == null:
		return
	var old_steps := _schedule.steps.duplicate()
	var new_steps := f.call(old_steps)
	if _undo == null:
		_schedule.steps = new_steps
		_rebuild()
		return
	_undo.create_action(action_name)
	_undo.add_do_property(_schedule, "steps", new_steps)
	_undo.add_undo_property(_schedule, "steps", old_steps)
	_undo.commit_action()
	_rebuild()


func _is_step_valid(step: NpcScheduleStep) -> bool:
	return step != null and step.is_valid()


func _on_create_spawn_point() -> void:
	if _fd_save_spawn != null:
		_fd_save_spawn.popup_centered_ratio(0.6)


func _on_create_route() -> void:
	if _fd_save_route != null:
		_fd_save_route.popup_centered_ratio(0.6)


func _on_pick_route_selected(path: String) -> void:
	var step := _pending_route_step
	_pending_route_step = null
	var res := load(path)
	if step != null and res is RouteResource:
		_set_step_prop(step, "route_res", res)


func _on_pick_spawn_selected(path: String) -> void:
	var target_step := _pending_spawn_target_step
	var target_point := _pending_spawn_target_point
	_pending_spawn_target_step = null
	_pending_spawn_target_point = null

	var res := load(path)
	if not (res is SpawnPointData):
		return
	if target_step != null:
		_set_step_prop(target_step, "hold_spawn_point", res)
	elif target_point != null:
		_set_point_prop(target_point, "spawn_point", res)


func _on_save_spawn_selected(path: String) -> void:
	var sp := SpawnPointData.new()
	sp.display_name = path.get_file().get_basename()
	var err := ResourceSaver.save(sp, path)
	if err == OK and _editor_interface != null:
		_editor_interface.edit_resource(sp)


func _on_save_route_selected(path: String) -> void:
	var r := RouteResource.new()
	r.route_name = StringName(path.get_file().get_basename())
	var err := ResourceSaver.save(r, path)
	if err == OK and _editor_interface != null:
		_editor_interface.edit_resource(r)


func _mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _short_path_last_dir_file(p: String) -> String:
	if p.is_empty():
		return ""
	var dir := p.get_base_dir().get_file()
	var file := p.get_file()
	if dir.is_empty():
		return file
	return "%s/%s" % [dir, file]
