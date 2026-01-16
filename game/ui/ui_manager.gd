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
	CHARACTER_CREATION = 11,
	BLACKSMITH_MENU = 12,
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
const _BLACKSMITH_MENU_SCENE: PackedScene = preload("res://game/ui/blacksmith/blacksmith_menu.tscn")
const _SETTINGS_MENU_SCENE: PackedScene = preload("res://game/ui/settings_menu/settings_menu.tscn")
const _REWARD_POPUP_SCENE: PackedScene = preload("res://game/ui/reward/reward_popup.tscn")
const _REWARD_PRESENTATION_SCENE: PackedScene = preload(
	"res://game/ui/reward/reward_presentation.tscn"
)
const _CHARACTER_CREATION_SCENE: PackedScene = preload(
	"res://game/ui/character_creation/character_creation_screen.tscn"
)
const _MODAL_CONFIRM_SCENE: PackedScene = preload("res://game/ui/modal_confirm/modal_confirm.tscn")

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
	ScreenName.BLACKSMITH_MENU: _BLACKSMITH_MENU_SCENE,
	ScreenName.SETTINGS_MENU: _SETTINGS_MENU_SCENE,
	ScreenName.REWARD_POPUP: _REWARD_POPUP_SCENE,
	ScreenName.REWARD_PRESENTATION: _REWARD_PRESENTATION_SCENE,
	ScreenName.CHARACTER_CREATION: _CHARACTER_CREATION_SCENE,
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
	ScreenName.BLACKSMITH_MENU: null,
	ScreenName.SETTINGS_MENU: null,
	ScreenName.REWARD_POPUP: null,
	ScreenName.REWARD_PRESENTATION: null,
	ScreenName.CHARACTER_CREATION: null,
}

var _ui_layer: CanvasLayer = null
var _toast_label: Label = null
var _loading_screen_refcount: int = 0
var _blackout_depth: int = 0
var _theme: Theme = null

# Quest notifications can fire during modal flows (e.g. GRANT_REWARD presentation).
# QuestPopupQueue will buffer events while `_should_defer_quest_notifications()` is true.

var _quest_popups: QuestPopupQueue = null


func _ready() -> void:
	# Keep UI alive while the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scene changes happen via runtime services; keep UI in an autoload so it persists.
	call_deferred("_ensure_ui_layer")
	call_deferred("_ensure_theme")
	_bind_quest_notifications()
	# Menu visibility is controlled by Runtime-owned GameFlow.


## Show a blocking Yes/No confirm modal and return the chosen value.
## - Returns true for Yes, false for No/cancel/failure.
## - Safe to call while paused; ModalConfirm uses PROCESS_MODE_ALWAYS.
func confirm(
	message: String,
	yes_label: String = "Yes",
	no_label: String = "No",
	icon: Texture2D = null,
	count: int = 0,
) -> bool:
	# Keep headless tests deterministic and avoid UI churn.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return false
	if Engine.is_editor_hint() or _MODAL_CONFIRM_SCENE == null:
		return false

	var inst := _MODAL_CONFIRM_SCENE.instantiate()
	if inst == null:
		return false

	# This modal is a CanvasLayer; attach to the root (not under UIRoot CanvasLayer).
	var root := get_tree().root
	if root == null:
		inst.queue_free()
		return false
	root.add_child(inst)
	_bring_to_front(inst)
	if inst.has_method("set_message"):
		inst.call("set_message", message)
	if inst.has_method("set_labels"):
		inst.call("set_labels", yes_label, no_label)
	if inst.has_method("set_icon"):
		inst.call("set_icon", icon)
	if inst.has_method("set_count"):
		inst.call("set_count", count)

	if inst.has_signal("decided"):
		return bool(await inst.decided)
	# Fallback: if the signal is missing, auto-dismiss as "No".
	inst.queue_free()
	return false


func _ensure_quest_popups() -> void:
	if _quest_popups != null:
		return
	_quest_popups = (
		QuestPopupQueue
		. new(
			self,
			Callable(self, "_should_defer_quest_notifications"),
			Callable(self, "_show_quest_popup_event"),
		)
	)


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
	if _try_update_visible_reward_popup("started", quest_id, 0):
		return
	_ensure_quest_popups()
	_quest_popups.enqueue(_build_quest_popup_event_started(quest_id))


func _on_quest_step_completed(quest_id: StringName, step_index: int) -> void:
	# If this was the final step, skip the step popup to avoid clashing with quest_completed.
	if QuestManager != null:
		var def: QuestResource = QuestManager.get_quest_definition(quest_id) as QuestResource
		if def != null and def.steps != null and (int(step_index) + 1) >= def.steps.size():
			return
	if _try_update_visible_reward_popup("step", quest_id, int(step_index)):
		return
	_ensure_quest_popups()
	_quest_popups.enqueue(_build_quest_popup_event_step(quest_id, int(step_index)))


func _on_quest_completed(quest_id: StringName) -> void:
	if _try_update_visible_reward_popup("completed", quest_id, 0):
		return
	_ensure_quest_popups()
	_quest_popups.enqueue(_build_quest_popup_event_completed(quest_id))


func _show_quest_popup_event(ev: QuestPopupQueue.Event) -> void:
	if ev == null:
		return

	# Skip stale quest popups: if the quest advanced/completed since this was queued,
	# don't show it (and don't wait the full duration in the queue pump).
	if _is_quest_popup_event_stale(ev):
		ev.duration = 0.0
		return

	var kind := ev.kind
	var title := ev.title.strip_edges()
	var heading := ev.heading.strip_edges()
	var entries: Array = ev.entries
	var duration := ev.duration
	if title.is_empty():
		title = "Quest"

	var node := show_screen(int(ScreenName.REWARD_POPUP))
	if node != null:
		if node.has_method("show_quest_event"):
			node.call("show_quest_event", ev)
			return
		if node.has_method("show_popup"):
			node.call("show_popup", title, heading, entries, duration, true)
			return
	# Fallback: toast for headless/unavailable UI.
	if kind == "completed":
		show_toast("Quest complete: %s" % title, duration)
	elif kind == "started":
		show_toast("New quest: %s" % title, duration)
	else:
		show_toast("Quest update: %s" % title, duration)


func _is_quest_popup_event_stale(ev: QuestPopupQueue.Event) -> bool:
	var stale := false
	if ev == null:
		stale = true
	elif QuestManager == null:
		stale = false
	else:
		var quest_id: StringName = ev.quest_id
		if String(quest_id).is_empty():
			stale = false
		else:
			var kind := String(ev.kind)
			if kind == "completed":
				stale = not bool(QuestManager.is_quest_completed(quest_id))
			else:
				var is_active := bool(QuestManager.is_quest_active(quest_id))
				if not is_active:
					stale = true
				else:
					var step := int(QuestManager.get_active_quest_step(quest_id))
					if kind == "started":
						stale = step != 0
					elif kind == "step":
						stale = step != (int(ev.step_index) + 1)
					else:
						stale = false
	return stale


func _try_update_visible_reward_popup(kind: String, quest_id: StringName, step_index: int) -> bool:
	# Prefer updating an already-visible quest popup (avoids duplicate queued popups).
	if String(quest_id).is_empty():
		return false
	if _should_defer_quest_notifications():
		return false
	var node := get_screen_node(ScreenName.REWARD_POPUP)
	if node == null or not is_instance_valid(node):
		return false
	# Only update in-place if it's already on screen.
	if not bool(node.visible):
		return false
	if not node.has_method("handle_quest_signal"):
		return false
	return bool(node.call("handle_quest_signal", String(kind), quest_id, int(step_index)))


func _build_quest_popup_event_started(quest_id: StringName) -> QuestPopupQueue.Event:
	var title := _format_quest_title(quest_id)
	var obj := QuestUiHelper.build_objective_display_for_quest_step(quest_id, 0, QuestManager)
	var entries: Array = []
	if obj != null:
		entries = [obj]
	var event := QuestPopupQueue.Event.new()
	event.kind = "started"
	event.quest_id = quest_id
	event.title = title
	event.heading = "NEW QUEST"
	event.entries = entries
	event.duration = 4.0
	return event


func _build_quest_popup_event_step(
	quest_id: StringName, completed_step_index: int
) -> QuestPopupQueue.Event:
	var title := _format_quest_title(quest_id)
	var obj := QuestUiHelper.build_next_objective_display(
		quest_id, completed_step_index, QuestManager
	)
	var entries: Array = []
	if obj != null:
		entries = [obj]
	var event := QuestPopupQueue.Event.new()
	event.kind = "step"
	event.quest_id = quest_id
	event.step_index = completed_step_index
	event.title = title
	event.heading = "QUEST UPDATE"
	event.entries = entries
	event.duration = 4.0
	return event


func _build_quest_popup_event_completed(quest_id: StringName) -> QuestPopupQueue.Event:
	var title := _format_quest_title(quest_id)
	var entries: Array = []
	if QuestManager != null:
		var def: QuestResource = QuestManager.get_quest_definition(quest_id) as QuestResource
		if def != null and def.completion_rewards != null and not def.completion_rewards.is_empty():
			entries = QuestUiHelper.build_reward_displays(def.completion_rewards)
	var event := QuestPopupQueue.Event.new()
	event.kind = "completed"
	event.quest_id = quest_id
	event.title = title
	event.heading = "QUEST COMPLETE"
	event.entries = entries
	event.duration = 4.0
	return event


func _should_defer_quest_notifications() -> bool:
	# Only show quest notifications during normal gameplay.
	# (Entering PAUSED currently briefly shows HUD during transition; this prevents
	# QuestPopupQueue from pumping during that window.)
	if Runtime != null and Runtime.game_flow != null:
		if Runtime.game_flow.get_active_state() != GameStateNames.IN_GAME:
			return true

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


func flush_queued_quest_notifications() -> void:
	_ensure_quest_popups()
	if _quest_popups == null:
		return
	_quest_popups.ensure_initial_delay(0.6)
	_quest_popups.pump()


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
	elif screen == ScreenName.CHARACTER_CREATION:
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
	# Avoid overlapping quest popups with certain modal/fullscreen screens.
	# NOTE: We intentionally do NOT hide quest popups for PAUSE_MENU / PLAYER_MENU:
	# they should stay visible, and we only explicitly dismiss them for dialogue/cutscene.
	if (
		screen == int(ScreenName.MAIN_MENU)
		or screen == int(ScreenName.LOAD_GAME_MENU)
		or screen == int(ScreenName.SETTINGS_MENU)
	):
		hide_screen(int(ScreenName.REWARD_POPUP))

	var node := _screen_nodes[screen]
	if node != null and is_instance_valid(node):
		node.visible = true
		_bring_to_front(node)
		# Pause/Player menus can cover the screen; keep quest popup above them if visible.
		if screen == int(ScreenName.PAUSE_MENU) or screen == int(ScreenName.PLAYER_MENU):
			var rp := get_screen_node(ScreenName.REWARD_POPUP) as CanvasItem
			if rp != null and is_instance_valid(rp) and bool(rp.visible):
				_bring_to_front(rp)
		# When gameplay HUD becomes visible, allow queued quest popups to run.
		if screen == int(ScreenName.HUD):
			_ensure_quest_popups()
			_quest_popups.ensure_initial_delay(0.6)
			_quest_popups.pump()
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
	# Ensure newly created screens actually render.
	# (Some scenes may have `visible = false` in their .tscn.)
	inst.visible = true

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
		_ensure_quest_popups()
		_quest_popups.ensure_initial_delay(0.6)
		_quest_popups.pump()
	_bring_to_front(inst)
	# Pause/Player menus can cover the screen; keep quest popup above them if visible.
	if screen == int(ScreenName.PAUSE_MENU) or screen == int(ScreenName.PLAYER_MENU):
		var rp := get_screen_node(ScreenName.REWARD_POPUP) as CanvasItem
		if rp != null and is_instance_valid(rp) and bool(rp.visible):
			_bring_to_front(rp)
	return inst


func _apply_theme_to_canvas_layer_screen(cl: CanvasLayer) -> void:
	if cl == null or _theme == null:
		return
	# CanvasLayers don't participate in Control theme inheritance, so apply to the first Control.
	for child in cl.get_children():
		if child is Control:
			var c := child as Control
			# Respect per-screen themes (e.g. silver system menus).
			if c.theme == null:
				c.theme = _theme
			return


func _apply_theme_to_control_screen(node: Node) -> void:
	if node == null or _theme == null:
		return
	if node is Control:
		var c := node as Control
		# Respect per-screen themes (e.g. silver system menus).
		if c.theme == null:
			c.theme = _theme


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
			_ensure_quest_popups()
			_quest_popups.pump()


func hide_all_menus() -> void:
	hide(ScreenName.PAUSE_MENU)
	hide(ScreenName.LOAD_GAME_MENU)
	hide(ScreenName.MAIN_MENU)
	hide(ScreenName.CHARACTER_CREATION)
	hide(ScreenName.PLAYER_MENU)
	hide(ScreenName.SHOP_MENU)
	hide(ScreenName.BLACKSMITH_MENU)
	hide(ScreenName.SETTINGS_MENU)
	hide(ScreenName.REWARD_PRESENTATION)
	hide(ScreenName.HUD)


## Explicitly dismiss quest notifications (and drop queued ones).
## Intended for dialogue/cutscene starts (cinematic context).
func dismiss_quest_notifications() -> void:
	hide(ScreenName.REWARD_POPUP)
	if _quest_popups != null:
		_quest_popups.clear()


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
