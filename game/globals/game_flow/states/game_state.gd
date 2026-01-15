class_name GameState
extends State

## Base class for GameFlow states.
## State instances are Nodes that operate on their parent GameFlow node.

var flow: Node = null


func _init(game_flow: Node = null) -> void:
	# Backwards-compatible with the previous RefCounted-based state init that did `.new(self)`.
	# Once GameFlow moves to node-children, we still bind via `bind_parent`.
	if game_flow != null:
		bind_parent(game_flow)


func bind_parent(new_parent: Node) -> void:
	super.bind_parent(new_parent)
	flow = new_parent


func enter(_prev: StringName = &"") -> void:
	pass


func exit(_next: StringName = &"") -> void:
	pass


## Re-assert the state's effects (e.g. after a scene load).
func refresh() -> void:
	enter()


## Called when another overlay state is pushed above this state.
func on_cover(_overlay: StringName) -> void:
	pass


## Called when an overlay state above this state is popped.
func on_reveal(_overlay: StringName) -> void:
	pass


func _overlay_enter(
	pause_reason: StringName, show_screen: int, hide_screens: Array[int] = []
) -> Node:
	if flow == null:
		return null

	flow.get_tree().paused = true
	if TimeManager != null:
		TimeManager.pause(pause_reason)
	GameplayUtils.set_player_input_enabled(flow.get_tree(), false)

	if UIManager != null:
		for screen in hide_screens:
			UIManager.hide(screen)
		return UIManager.show(show_screen)

	return null


func _overlay_reassert(
	pause_reason: StringName, show_screen: int, hide_screens: Array[int] = []
) -> void:
	_overlay_enter(pause_reason, show_screen, hide_screens)


func _overlay_cover(screen: int) -> void:
	if UIManager != null:
		UIManager.hide(screen)


func _overlay_exit(pause_reason: StringName, hide_screen: int) -> void:
	if UIManager != null:
		UIManager.hide(hide_screen)
	if TimeManager != null:
		TimeManager.resume(pause_reason)
	if flow != null:
		GameplayUtils.set_player_input_enabled(flow.get_tree(), true)


## Return the next state to transition to, or `GameStateNames.NONE` to stay in the current state.
func handle_unhandled_input(_event: InputEvent) -> StringName:
	return GameStateNames.NONE


## Helper to transition to a level with loading screen, hydration, and setup.
func _transition_to_level(
	level_id: Enums.Levels, options: Dictionary = {}, setup_fn: Callable = Callable()
) -> void:
	if flow == null:
		return

	await flow.run_loading_action(
		func() -> bool:
			if setup_fn.is_valid():
				await setup_fn.call()

			if Runtime == null or Runtime.scene_loader == null:
				return false

			return await Runtime.scene_loader.load_level_and_hydrate(level_id, options)
	)


func start_new_game() -> bool:
	return await flow.run_loading_action(func() -> bool: return true)


func continue_session() -> bool:
	return await flow.run_loading_action(func() -> bool: return true)


func perform_level_change(
	_target_level_id: Enums.Levels, _fallback_spawn_point: SpawnPointData = null
) -> bool:
	return await flow.run_loading_action(func() -> bool: return true)


func check_player_menu_input(event: InputEvent) -> bool:
	# Player menu toggle: only while actively playing.
	if event.is_action_pressed(&"open_player_menu"):
		if flow.get_player() != null:
			flow.request_player_menu(-1)
			return true
	# Open inventory tab.
	if event.is_action_pressed(&"open_player_menu_inventory"):
		if flow.get_player() != null:
			flow.request_player_menu(PlayerMenu.Tab.INVENTORY)
			return true
	# Open quests tab.
	if event.is_action_pressed(&"open_player_menu_quests"):
		if flow.get_player() != null:
			flow.request_player_menu(PlayerMenu.Tab.QUESTS)
			return true
	# Open relationships tab.
	if event.is_action_pressed(&"open_player_menu_relationships"):
		if flow.get_player() != null:
			flow.request_player_menu(PlayerMenu.Tab.RELATIONSHIPS)
			return true

	return false
