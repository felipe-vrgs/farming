@tool
class_name SpawnMarker
extends Marker2D

@export var spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

func _enter_tree() -> void:
	# Make it easy to find markers without relying on node names or paths.
	add_to_group(Groups.SPAWN_MARKERS)


