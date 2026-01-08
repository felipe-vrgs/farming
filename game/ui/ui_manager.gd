extends Node

## UIManager (v0)
## Start of a global UI manager that survives scene changes.
## Owns global UI overlays (menu, pause, loading, debug clock).

const _UI_THEME: Theme = preload("res://game/ui/theme/ui_theme.tres")

enum ScreenName {
	MAIN_MENU = 0,
	LOAD_GAME_MENU = 1,
	PAUSE_MENU = 2,
	LOADING_SCREEN = 3,
	VIGNETTE = 4,
	HUD = 5,
	PLAYER_MENU = 6,
	SHOP_MENU = 7,
	SETTINGS_MENU = 8,
	REWARD_POPUP = 9,
	REWARD_PRESENTATION = 10,
}

const _GAME_MENU_SCENE: PackedScene = preload("res://game/ui/game_menu/game_menu.tscn")
const _LOAD_GAME_MENU_SCENE: PackedScene = preload("res://game/ui/game_menu/load_game_menu.tscn")
const _PAUSE_MENU_SCENE: PackedScene = preload("res://game/ui/pause_menu/pause_menu.tscn")
const _LOADING_SCREEN_SCENE: PackedScene = preload(
	"res://game/ui/loading_screen/loading_screen.tscn"
)
const _VIGNETTE_SCENE: PackedScene = preload("res://game/ui/vignette/vignette.tscn")
const _HUD_SCENE: PackedScene = preload("res://game/ui/hud/hud.tscn")
const _PLAYER_MENU_SCENE: PackedScene = preload("res://game/ui/player_menu/player_menu.tscn")
const _SHOP_MENU_SCENE: PackedScene = preload("res://game/ui/shop/shop_menu.tscn")
const _SETTINGS_MENU_SCENE: PackedScene = preload("res://game/ui/settings_menu/settings_menu.tscn")
const _REWARD_POPUP_SCENE: PackedScene = preload("res://game/ui/reward/reward_popup.tscn")
const _REWARD_PRESENTATION_SCENE: PackedScene = preload(
	"res://game/ui/reward/reward_presentation.tscn"
)

const _UI_ROOT_LAYER := 50
# Any UI screen scene that is itself a CanvasLayer must render above world overlays (day/night, etc)
const _CANVAS_UI_MIN_LAYER := 60

const _SCREEN_SCENES: Dictionary[int, PackedScene] = {
	ScreenName.MAIN_MENU: _GAME_MENU_SCENE,
	ScreenName.LOAD_GAME_MENU: _LOAD_GAME_MENU_SCENE,
	ScreenName.PAUSE_MENU: _PAUSE_MENU_SCENE,
	ScreenName.LOADING_SCREEN: _LOADING_SCREEN_SCENE,
	ScreenName.VIGNETTE: _VIGNETTE_SCENE,
	ScreenName.HUD: _HUD_SCENE,
	ScreenName.PLAYER_MENU: _PLAYER_MENU_SCENE,
	ScreenName.SHOP_MENU: _SHOP_MENU_SCENE,
	ScreenName.SETTINGS_MENU: _SETTINGS_MENU_SCENE,
	ScreenName.REWARD_POPUP: _REWARD_POPUP_SCENE,
	ScreenName.REWARD_PRESENTATION: _REWARD_PRESENTATION_SCENE,
}

var _screen_nodes: Dictionary[int, Node] = {
	ScreenName.MAIN_MENU: null,
	ScreenName.LOAD_GAME_MENU: null,
	ScreenName.PAUSE_MENU: null,
	ScreenName.LOADING_SCREEN: null,
	ScreenName.VIGNETTE: null,
	ScreenName.HUD: null,
	ScreenName.PLAYER_MENU: null,
	ScreenName.SHOP_MENU: null,
	ScreenName.SETTINGS_MENU: null,
	ScreenName.REWARD_POPUP: null,
	ScreenName.REWARD_PRESENTATION: null,
}

var _ui_layer: CanvasLayer = null
var _toast_label: Label = null
var _loading_screen_refcount: int = 0
var _blackout_depth: int = 0
var _theme: Theme = null

# Quest notifications can fire during modal flows (e.g. GRANT_REWARD presentation).
# Queue them and flush once overlays are closed.
var _queued_quest_step_events: Array[Dictionary] = []  # {quest_id: StringName, step_index: int}
var _queued_quest_started: Array[StringName] = []
var _queued_quest_completed: Array[StringName] = []

var _quest_popup_queue: Array[Dictionary] = []  # {type:String, quest_id:StringName, step_index:int}
var _quest_popup_pumping: bool = false
var _quest_popup_initial_delay_sec: float = 0.0


func _ready() -> void:
	# Keep UI alive while the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scene changes happen via runtime services; keep UI in an autoload so it persists.
	call_deferred("_ensure_ui_layer")
	call_deferred("_ensure_theme")
	_bind_quest_notifications()
	# Menu visibility is controlled by Runtime-owned GameFlow.


func _bind_quest_notifications() -> void:
	# Keep headless tests deterministic and avoid UI node churn/leaks.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return
	if Engine.is_editor_hint():
		return
	if EventBus == null:
		return

	if "quest_started" in EventBus and not EventBus.quest_started.is_connected(_on_quest_started):
		EventBus.quest_started.connect(_on_quest_started)
	if (
		"quest_step_completed" in EventBus
		and not EventBus.quest_step_completed.is_connected(_on_quest_step_completed)
	):
		EventBus.quest_step_completed.connect(_on_quest_step_completed)
	if (
		"quest_completed" in EventBus
		and not EventBus.quest_completed.is_connected(_on_quest_completed)
	):
		EventBus.quest_completed.connect(_on_quest_completed)


func _on_quest_started(quest_id: StringName) -> void:
	if _should_defer_quest_notifications():
		_queued_quest_started.append(quest_id)
		return
	_enqueue_quest_popup({"type": "started", "quest_id": quest_id})


func _show_quest_started(quest_id: StringName) -> void:
	var title := _format_quest_title(quest_id)
	var row := _get_quest_objective_row(quest_id, 0)
	var node := show_screen(int(ScreenName.REWARD_POPUP))
	if node != null and node.has_method("show_quest_started"):
		# Show "NEW QUEST" and include the next objective like an in-progress update.
		node.call(
			"show_quest_started",
			title,
			String(row.get("text", "")),
			row.get("icon") as Texture2D,
			4.0
		)
	else:
		show_toast("New quest: %s" % title, 4.0)


func _on_quest_step_completed(quest_id: StringName, step_index: int) -> void:
	if _should_defer_quest_notifications():
		_queued_quest_step_events.append({"quest_id": quest_id, "step_index": int(step_index)})
		return
	# If this was the final step, skip the step popup to avoid clashing with quest_completed.
	if QuestManager != null:
		var def: QuestResource = QuestManager.get_quest_definition(quest_id) as QuestResource
		if def != null and def.steps != null and (int(step_index) + 1) >= def.steps.size():
			return
	_enqueue_quest_popup({"type": "step", "quest_id": quest_id, "step_index": int(step_index)})


func _show_quest_step_completed(quest_id: StringName, step_index: int) -> void:
	var title := _format_quest_title(quest_id)
	var row := _get_quest_objective_row(quest_id, int(step_index) + 1)

	var node := show_screen(int(ScreenName.REWARD_POPUP))
	if node != null and node.has_method("show_quest_update"):
		node.call(
			"show_quest_update",
			title,
			String(row.get("text", "")),
			row.get("icon") as Texture2D,
			4.0
		)


func _on_quest_completed(quest_id: StringName) -> void:
	if _should_defer_quest_notifications():
		_queued_quest_completed.append(quest_id)
		return
	_enqueue_quest_popup({"type": "completed", "quest_id": quest_id})


func _show_quest_completed(quest_id: StringName) -> void:
	var title := _format_quest_title(quest_id)
	var reward := _get_quest_completion_reward_preview(quest_id)
	var reward_icon: Texture2D = reward.get("icon") as Texture2D
	var reward_count := int(reward.get("count", 1))
	var node := show_screen(int(ScreenName.REWARD_POPUP))
	if node != null and node.has_method("show_quest_completed"):
		node.call("show_quest_completed", title, reward_icon, reward_count, 4.0)
	else:
		show_toast("Quest complete: %s" % title, 4.0)


func _get_quest_completion_reward_preview(quest_id: StringName) -> Dictionary:
	# Best-effort: show the first item reward icon on quest completion.
	# (Money rewards currently have no icon.)
	if QuestManager == null:
		return {}
	var def: QuestResource = QuestManager.get_quest_definition(quest_id) as QuestResource
	if def == null or def.completion_rewards == null or def.completion_rewards.is_empty():
		return {}
	for r in def.completion_rewards:
		if r == null:
			continue
		if r is QuestRewardItem:
			var ri := r as QuestRewardItem
			if ri.item != null and ri.item.icon != null:
				return {"icon": ri.item.icon, "count": int(ri.count)}
	return {}


func flush_queued_quest_notifications() -> void:
	# Public hook for modal flows (e.g. GRANT_REWARD) to flush after closing overlays.
	if _should_defer_quest_notifications():
		return

	var steps := _queued_quest_step_events
	var starts := _queued_quest_started
	var completes := _queued_quest_completed
	_queued_quest_step_events = []
	_queued_quest_started = []
	_queued_quest_completed = []

	for qid in starts:
		if not String(qid).is_empty():
			_enqueue_quest_popup({"type": "started", "quest_id": qid})

	for e in steps:
		if e == null:
			continue
		var qid: StringName = e.get("quest_id", &"") as StringName
		var idx := int(e.get("step_index", -1))
		if not String(qid).is_empty() and idx >= 0:
			_enqueue_quest_popup({"type": "step", "quest_id": qid, "step_index": idx})

	for qid in completes:
		if not String(qid).is_empty():
			_enqueue_quest_popup({"type": "completed", "quest_id": qid})


func _enqueue_quest_popup(ev: Dictionary) -> void:
	if ev == null:
		return
	var typ := String(ev.get("type", ""))
	if typ == "completed":
		# Ensure quest completion is shown before any queued quest-started popups
		# (e.g. when completing a quest auto-starts the next unlocked quest).
		var qid: StringName = ev.get("quest_id", &"") as StringName
		if not String(qid).is_empty():
			# Also remove any queued step popups for this quest (avoid clashes).
			for i in range(_quest_popup_queue.size() - 1, -1, -1):
				var e := _quest_popup_queue[i]
				if e is Dictionary and String(e.get("type", "")) == "step":
					if (e.get("quest_id", &"") as StringName) == qid:
						_quest_popup_queue.remove_at(i)
		_quest_popup_queue.insert(0, ev)
	else:
		_quest_popup_queue.append(ev)
	_pump_quest_popups()


func _pump_quest_popups() -> void:
	if _quest_popup_pumping:
		return
	_quest_popup_pumping = true
	_call_pump_async()


func _call_pump_async() -> void:
	# Run async without blocking signal handler stack.
	call_deferred("_pump_quest_popups_async")


func _pump_quest_popups_async() -> void:
	await _pump_quest_popups_loop()


func _pump_quest_popups_loop() -> void:
	while not _quest_popup_queue.is_empty():
		# If a modal overlay is visible, stop pumping until it closes.
		if _should_defer_quest_notifications():
			break
		# One-time delay to avoid the popup getting hidden by initial game start UI churn.
		if _quest_popup_initial_delay_sec > 0.0:
			var d := _quest_popup_initial_delay_sec
			_quest_popup_initial_delay_sec = 0.0
			await get_tree().create_timer(d, true).timeout
		var ev = _quest_popup_queue.pop_front()
		if ev == null:
			continue
		var typ := String(ev.get("type", ""))
		if typ == "started":
			_show_quest_started(ev.get("quest_id", &"") as StringName)
			await get_tree().create_timer(4.35, true).timeout
		elif typ == "step":
			_show_quest_step_completed(
				ev.get("quest_id", &"") as StringName, int(ev.get("step_index", -1))
			)
			await get_tree().create_timer(4.35, true).timeout
		elif typ == "completed":
			_show_quest_completed(ev.get("quest_id", &"") as StringName)
			await get_tree().create_timer(4.35, true).timeout

	_quest_popup_pumping = false


func _get_quest_objective_row(quest_id: StringName, step_idx: int) -> Dictionary:
	# Returns {text:String, icon:Texture2D}
	if QuestManager == null:
		return {}
	if String(quest_id).is_empty():
		return {}
	var def: QuestResource = QuestManager.get_quest_definition(quest_id) as QuestResource
	if def == null or def.steps == null:
		return {}
	if step_idx < 0 or step_idx >= def.steps.size():
		return {}
	var st: QuestStep = def.steps[step_idx]
	if st == null:
		return {}

	var label := ""
	var icon: Texture2D = null
	var progress := 0
	var target := 1

	if st.objective != null:
		label = String(st.objective.describe())
		target = maxi(1, int(st.objective.target_count))
		if QuestManager.has_method("get_objective_progress"):
			progress = int(QuestManager.get_objective_progress(quest_id, step_idx))

		# Replace raw item_id with display name where possible (match QuestPanel behavior).
		if st.objective is QuestObjectiveItemCount:
			var o := st.objective as QuestObjectiveItemCount
			var item := QuestUiHelper.resolve_item_data(o.item_id)
			if item != null:
				icon = item.icon
				if not item.display_name.is_empty():
					label = label.replace(String(o.item_id), item.display_name)
		elif st.objective is QuestObjectiveTalk:
			var o2 := st.objective as QuestObjectiveTalk
			icon = QuestUiHelper.resolve_npc_icon(o2.npc_id)
	else:
		label = String(st.description)

	label = label.strip_edges()
	if not label.is_empty():
		label = "%s (%s)" % [label, QuestUiHelper.format_progress(progress, target)]

	return {"text": label, "icon": icon}


func _should_defer_quest_notifications() -> bool:
	# If the reward presentation overlay is visible, defer quest popups until it closes.
	var n := get_screen_node(ScreenName.REWARD_PRESENTATION)
	if n != null and is_instance_valid(n) and bool(n.visible):
		return true
	# Also defer until the HUD is visible; during game start/loading we hide all menus and
	# quest popups can get immediately hidden before the player ever sees them.
	var hud := get_screen_node(ScreenName.HUD)
	if hud == null or not is_instance_valid(hud):
		return true
	return not bool(hud.visible)


func _format_quest_title(quest_id: StringName) -> String:
	var fallback := String(quest_id)
	if fallback.is_empty():
		fallback = "Quest"
	if QuestManager == null:
		return fallback
	var def = QuestManager.get_quest_definition(quest_id)
	if def != null and "title" in def and not String(def.title).is_empty():
		return String(def.title)
	return fallback


func show(screen: ScreenName) -> Node:
	# Some screens "replace" others.
	if screen == ScreenName.LOAD_GAME_MENU:
		# Prevent two full-screen menus fighting for attention.
		hide(ScreenName.MAIN_MENU)

	var node := show_screen(int(screen))
	if node != null:
		_bring_to_front(node)

	return node


## Acquire the global loading screen overlay (reference counted).
## This prevents flicker when multiple systems fade around the same time.
func acquire_loading_screen() -> LoadingScreen:
	_loading_screen_refcount += 1
	var node := show(ScreenName.LOADING_SCREEN)
	return node as LoadingScreen


## Release the loading screen overlay acquired by acquire_loading_screen().
func release_loading_screen() -> void:
	_loading_screen_refcount = maxi(0, _loading_screen_refcount - 1)
	if _loading_screen_refcount > 0:
		return
	hide(ScreenName.LOADING_SCREEN)


## Begin a nested blackout transaction (fade to black and keep it black).
## Reference-counted: only the first call performs the fade-out.
func blackout_begin(time: float = 0.25) -> void:
	_blackout_depth += 1
	if _blackout_depth != 1:
		return

	var loading := acquire_loading_screen()
	if loading == null:
		# Roll back so we don't get stuck "in blackout".
		_blackout_depth = 0
		return
	await loading.fade_out(maxf(0.0, time))


## End a nested blackout transaction (fade back in and release overlay).
## Reference-counted: only the last call performs the fade-in.
func blackout_end(time: float = 0.25) -> void:
	_blackout_depth = maxi(0, _blackout_depth - 1)
	if _blackout_depth != 0:
		return

	var loading: LoadingScreen = null
	if has_method("get_screen_node"):
		loading = get_screen_node(ScreenName.LOADING_SCREEN) as LoadingScreen
	if loading != null:
		await loading.fade_in(maxf(0.0, time))
	release_loading_screen()


func get_screen_node(screen: ScreenName) -> Node:
	# Returns the node even if it is currently hidden (visible = false).
	return _screen_nodes.get(int(screen)) as Node


func hide(screen: ScreenName) -> void:
	hide_screen(int(screen))


func _ensure_ui_layer() -> void:
	var root := get_tree().root
	if root == null:
		return

	var existing := root.get_node_or_null(NodePath("UIRoot"))
	if existing is CanvasLayer:
		_ui_layer = existing as CanvasLayer
		return

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UIRoot"
	_ui_layer.layer = _UI_ROOT_LAYER
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.call_deferred("add_child", _ui_layer)


func _ensure_theme() -> void:
	if _theme != null and is_instance_valid(_theme):
		return
	_ensure_ui_layer()
	_theme = _UI_THEME


func show_screen(screen: int) -> Node:
	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = true
		_bring_to_front(node)
		# When gameplay HUD becomes visible, allow queued quest popups to run.
		if screen == int(ScreenName.HUD):
			_quest_popup_initial_delay_sec = maxf(_quest_popup_initial_delay_sec, 0.6)
			flush_queued_quest_notifications()
		if node.has_method("rebind"):
			if screen == ScreenName.HUD:
				node.call("rebind")
			elif screen == ScreenName.PLAYER_MENU:
				var p: Player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
				node.call("rebind", p)
		return node

	var inst := _SCREEN_SCENES[screen].instantiate()
	if inst == null:
		return null

	# CanvasLayer screens should attach to the root, not under UIRoot (also a CanvasLayer).
	if inst is CanvasLayer:
		# Ensure CanvasLayer UI screens are always above any "world overlay" CanvasLayers
		# (e.g., day/night lighting), and keep any explicit high layer (loading screen is 100).
		var cl := inst as CanvasLayer
		cl.layer = maxi(int(cl.layer), _CANVAS_UI_MIN_LAYER)
		get_tree().root.add_child(inst)
		_apply_theme_to_canvas_layer_screen(inst as CanvasLayer)
	else:
		_ensure_ui_layer()
		if _ui_layer == null:
			inst.queue_free()
			return null
		_ui_layer.add_child(inst)
		_apply_theme_to_control_screen(inst)

	_screen_nodes[screen] = inst
	if inst.has_method("rebind"):
		if screen == ScreenName.HUD:
			inst.call("rebind")
		elif screen == ScreenName.PLAYER_MENU:
			var p: Player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			inst.call("rebind", p)
	# When gameplay HUD becomes visible, allow queued quest popups to run.
	if screen == int(ScreenName.HUD):
		_quest_popup_initial_delay_sec = maxf(_quest_popup_initial_delay_sec, 0.6)
		flush_queued_quest_notifications()
	_bring_to_front(inst)
	return inst


func _apply_theme_to_canvas_layer_screen(cl: CanvasLayer) -> void:
	if cl == null or _theme == null:
		return
	# CanvasLayers don't participate in Control theme inheritance, so apply to the first Control.
	for child in cl.get_children():
		if child is Control:
			(child as Control).theme = _theme
			return


func _apply_theme_to_control_screen(node: Node) -> void:
	if node == null or _theme == null:
		return
	if node is Control:
		(node as Control).theme = _theme


func _bring_to_front(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var p := node.get_parent()
	if p == null:
		return
	p.move_child(node, p.get_child_count() - 1)


func rebind_hud(player: Player = null) -> void:
	var node: Node = _screen_nodes.get(ScreenName.HUD) as Node
	if node != null and is_instance_valid(node) and node.has_method("rebind"):
		node.call("rebind", player)


func hide_screen(screen: int) -> void:
	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = false
		# If we just closed the reward presentation overlay, flush queued quest notifications
		# that were deferred to avoid UI overlap during modal flows.
		if int(screen) == int(ScreenName.REWARD_PRESENTATION):
			flush_queued_quest_notifications()


func hide_all_menus() -> void:
	hide(ScreenName.PAUSE_MENU)
	hide(ScreenName.LOAD_GAME_MENU)
	hide(ScreenName.MAIN_MENU)
	hide(ScreenName.PLAYER_MENU)
	hide(ScreenName.SHOP_MENU)
	hide(ScreenName.SETTINGS_MENU)
	hide(ScreenName.REWARD_POPUP)
	hide(ScreenName.REWARD_PRESENTATION)
	hide(ScreenName.HUD)


func show_toast(text: String, duration: float = 1.5) -> void:
	_ensure_ui_layer()
	if _ui_layer == null:
		return

	if _toast_label == null or not is_instance_valid(_toast_label):
		_toast_label = Label.new()
		_toast_label.name = "ToastLabel"
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_toast_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_toast_label.anchor_left = 0.0
		_toast_label.anchor_right = 1.0
		_toast_label.anchor_top = 0.0
		_toast_label.anchor_bottom = 0.0
		_toast_label.offset_top = 8.0
		_toast_label.offset_bottom = 32.0
		_toast_label.modulate = Color(1, 1, 1, 1)
		_toast_label.process_mode = Node.PROCESS_MODE_ALWAYS
		if _theme != null:
			_toast_label.theme = _theme
		_ui_layer.add_child(_toast_label)

	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(max(0.1, duration))
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.25)
	tween.finished.connect(
		func():
			if _toast_label != null and is_instance_valid(_toast_label):
				_toast_label.visible = false
	)
