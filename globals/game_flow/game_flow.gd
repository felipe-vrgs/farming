extends Node

## GameFlow (v0)
## Centralized game flow state machine:
## - owns "what mode are we in" (menu / loading / in-game / paused)
## - owns pause menu + pause reasons
## - provides a single entry point for menu actions
##
## NOTE: This should be an Autoload so it survives `change_scene_to_file`.

signal state_changed(prev: int, next: int)

enum State {
	MAIN_MENU = 0,
	LOADING = 1,
	IN_GAME = 2,
	PAUSED = 3,
}

const _PAUSE_REASON_MENU := &"pause_menu"

const _PAUSE_MENU_SCENE: PackedScene = preload("res://ui/pause_menu/pause_menu.tscn")

var state: int = State.MAIN_MENU
var _pause_menu: Control = null

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)
	_refresh_state_from_scene()

func _process(_delta: float) -> void:
	# Keep state in sync with scene swaps driven by GameManager.
	if GameManager != null and GameManager.has_method("is_loading") and GameManager.is_loading():
		if state != State.LOADING:
			_set_state(State.LOADING)
		return

	# If we were loading and GameManager finished, infer next state from scene.
	if state == State.LOADING:
		_refresh_state_from_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	if not (event is InputEventKey) and not (event is InputEventJoypadButton):
		return

	# Don't allow pausing while loading.
	if GameManager != null and GameManager.has_method("is_loading") and GameManager.is_loading():
		return

	if event.is_action_pressed(&"pause"):
		if state == State.IN_GAME:
			pause()
		elif state == State.PAUSED:
			resume()

func _refresh_state_from_scene() -> void:
	# Best-effort: infer state from active scene type.
	var scene := get_tree().current_scene
	if scene is LevelRoot:
		_set_state(State.IN_GAME)
	else:
		_set_state(State.MAIN_MENU)

func _set_state(next: int) -> void:
	if state == next:
		return
	var prev := state
	state = next
	state_changed.emit(prev, next)

func pause() -> void:
	if state != State.IN_GAME:
		return

	_set_state(State.PAUSED)
	if TimeManager != null:
		TimeManager.pause(_PAUSE_REASON_MENU)

	var p := _get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", false)

	_show_pause_menu()

func resume() -> void:
	if state != State.PAUSED:
		return

	_hide_pause_menu()

	var p := _get_player()
	if p != null and p.has_method("set_input_enabled"):
		p.call("set_input_enabled", true)

	if TimeManager != null:
		TimeManager.resume(_PAUSE_REASON_MENU)
	_set_state(State.IN_GAME)

func start_new_game() -> void:
	if GameManager != null:
		GameManager.start_new_game()
	# GameManager will swap scenes; we will refresh state on next frames.

func continue_session() -> void:
	if GameManager != null:
		GameManager.continue_session()

func load_from_slot(slot: String) -> void:
	if GameManager != null:
		GameManager.load_from_slot(slot)

func return_to_main_menu() -> void:
	# Resume first to clear pause reasons/UI.
	if state == State.PAUSED:
		_hide_pause_menu()
		if TimeManager != null:
			TimeManager.resume(_PAUSE_REASON_MENU)

	# Best-effort: go back to main menu scene.
	get_tree().change_scene_to_file("res://main.tscn")
	call_deferred("_refresh_state_from_scene")

func _get_player() -> Node:
	var nodes := get_tree().get_nodes_in_group(Groups.PLAYER)
	if nodes.is_empty():
		return null
	return nodes[0] as Node

func _show_pause_menu() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.visible = true
		return

	var root := get_tree().root
	if root == null:
		return

	var inst := _PAUSE_MENU_SCENE.instantiate()
	if inst == null or not (inst is Control):
		if inst != null:
			inst.queue_free()
		return

	_pause_menu = inst as Control
	root.add_child(_pause_menu)

	# Wire callbacks if present (keep it decoupled).
	if _pause_menu.has_signal("resume_requested"):
		_pause_menu.connect("resume_requested", Callable(self, "resume"))
	if _pause_menu.has_signal("save_requested"):
		_pause_menu.connect("save_requested", Callable(self, "_on_pause_save_requested"))
	if _pause_menu.has_signal("load_requested"):
		_pause_menu.connect("load_requested", Callable(self, "_on_pause_load_requested"))
	if _pause_menu.has_signal("quit_to_menu_requested"):
		_pause_menu.connect("quit_to_menu_requested", Callable(self, "return_to_main_menu"))
	if _pause_menu.has_signal("quit_requested"):
		_pause_menu.connect("quit_requested", Callable(self, "_on_pause_quit_requested"))

func _hide_pause_menu() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null

func _on_pause_save_requested(slot: String) -> void:
	if GameManager == null:
		return
	# Save is allowed during pause.
	GameManager.save_to_slot(slot)

func _on_pause_load_requested(slot: String) -> void:
	# Loading should unpause + transition via GameManager.
	resume()
	load_from_slot(slot)

func _on_pause_quit_requested() -> void:
	get_tree().quit()

