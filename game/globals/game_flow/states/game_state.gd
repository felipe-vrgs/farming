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
