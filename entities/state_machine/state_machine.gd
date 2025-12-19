class_name StateMachine
extends Node

signal state_binding_requested(state: State)

@export var starting_state: State

var current_state: State
var _states: Dictionary = {}

# Initialize the state machine by asking interested listeners (e.g. Player)
# to bind themselves to each State, then enter the default starting_state.
func init() -> void:
	_cache_states()
	_request_state_binding()
	if starting_state:
		change_state(String(starting_state.name).to_snake_case())


func _cache_states() -> void:
	_states.clear()
	for child in get_children():
		if child is State:
			# Cache by snake_case string name for consistency with constants
			_states[StringName(String(child.name).to_snake_case())] = child


func _request_state_binding() -> void:
	for child in _states.values():
		state_binding_requested.emit(child)

## Get a state by its node name (e.g. "idle", "jump", "fall")
func get_state(state_name: StringName) -> State:
	return _states.get(state_name, null)

# Change to the new state by first calling any exit logic on the current state.
func change_state(new_state: StringName) -> void:
	if new_state == PlayerStateNames.NONE:
		return

	if current_state:
		current_state.exit()

	var new_state_node := get_state(new_state)
	current_state = new_state_node
	if current_state:
		current_state.enter()

# Pass through functions for the Player to call,
# handling state changes as needed.
func process_physics(delta: float) -> void:
	if not current_state:
		return
	var new_state = current_state.process_physics(delta)
	if new_state != PlayerStateNames.NONE:
		change_state(new_state)

func process_input(event: InputEvent) -> void:
	if not current_state:
		return
	var new_state = current_state.process_input(event)
	if new_state != PlayerStateNames.NONE:
		change_state(new_state)

func process_frame(delta: float) -> void:
	if not current_state:
		return
	var new_state = current_state.process_frame(delta)
	if new_state != PlayerStateNames.NONE:
		change_state(new_state)
