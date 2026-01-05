extends RefCounted

## Base class for GameFlow states.
## State instances are pure logic objects (RefCounted) that operate on the GameFlow node.

var flow: Node = null


func _init(game_flow: Node) -> void:
	flow = game_flow


func enter(_prev: int) -> void:
	pass


func exit(_next: int) -> void:
	pass


## Return true if the input event was handled/consumed by this state.
func handle_unhandled_input(_event: InputEvent) -> bool:
	return false
