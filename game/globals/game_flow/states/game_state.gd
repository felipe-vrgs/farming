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


## Return the next state to transition to, or `GameStateNames.NONE` to stay in the current state.
func handle_unhandled_input(_event: InputEvent) -> StringName:
	return GameStateNames.NONE
