class_name InteractableComponent
extends Node

## Base class for "interaction behaviors" that can be attached to an entity.
## Components are discovered via Groups.INTERACTABLE_COMPONENTS.

@export var priority: int = 0

func _enter_tree() -> void:
	add_to_group(Groups.INTERACTABLE_COMPONENTS)

func get_priority() -> int:
	return priority

func try_interact(_ctx: InteractionContext) -> bool:
	return false
