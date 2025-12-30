class_name SaveComponent
extends Node

## Helper to automate state saving for entities without writing code.
## Captures properties from the parent or specified child nodes.

## Emitted after state has been applied.
## Useful for parent nodes to re-initialize visuals or logic.
signal state_applied

## List of properties on the PARENT node to save (e.g. "days_grown", "variant").
@export var properties: Array[String] = []

## List of child nodes to scan.
## If a child has `get_save_state()`, it is called.
@export var child_nodes: Array[NodePath] = []

var _pending_state: Dictionary = {}
var _is_ready: bool = false

func _enter_tree() -> void:
	# Allow discovery without relying on node paths ("SaveComponent" vs "Components/SaveComponent").
	add_to_group(&"save_components")

func _ready() -> void:
	_is_ready = true
	if not _pending_state.is_empty():
		apply_save_state(_pending_state)
		_pending_state.clear()

func get_save_state() -> Dictionary:
	var state := {}
	var parent := get_parent()
	if parent == null:
		return state

	# 1. Capture Parent Properties
	for prop in properties:
		var val = parent.get(prop)
		if val != null:
			if val is Resource:
				var path := String((val as Resource).resource_path)
				# Godot 4 often uses `uid://...` resource paths when `.uid` files are present.
				# Only persist resources we can reliably reload.
				if path.begins_with("res://") or path.begins_with("uid://"):
					state[prop] = path
				else:
					# Skip embedded/unsaved resources (empty path) to avoid type corruption on load.
					# push_warning("SaveComponent: Skipping Resource prop '%s' with empty/unsupported path" % prop)
					pass
			else:
				state[prop] = val

	# 2. Capture Child Nodes
	for path in child_nodes:
		var node = parent.get_node_or_null(path)
		if node == null:
			continue

		if node.has_method("get_save_state"):
			var child_state = node.get_save_state()
			if child_state is Dictionary:
				state.merge(child_state)

	return state

func apply_save_state(state: Dictionary) -> void:
	if not _is_ready:
		_pending_state = state
		return

	var parent := get_parent()
	if parent == null:
		return

	# 1. Apply Parent Properties
	for prop in properties:
		if state.has(prop):
			var val = state[prop]
			if typeof(val) == TYPE_STRING:
				var s := val as String
				var is_loadable := s.begins_with("res://") or s.begins_with("uid://")
				if is_loadable:
					var res = load(s)
					if res != null:
						parent.set(prop, res)
					else:
						parent.set(prop, val)
					continue

			if typeof(val) == TYPE_STRING and (val as String).begins_with("res://"):
				var res = load(val)
				if res != null:
					parent.set(prop, res)
				else:
					parent.set(prop, val)
			else:
				parent.set(prop, val)

	# 2. Apply Child Nodes
	for path in child_nodes:
		var node = parent.get_node_or_null(path)
		if node != null and node.has_method("apply_save_state"):
			node.apply_save_state(state)

	state_applied.emit()
