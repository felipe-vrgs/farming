class_name WallPassZone
extends Area2D

## While inside this zone, player can pass through terrain (walls/cliffs).
## Used for stairs and similar transitions.


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Check for bodies already inside
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(Groups.PLAYER) or body is Player:
		if body.has_method("set_terrain_collision"):
			body.set_terrain_collision(false)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(Groups.PLAYER) or body is Player:
		if body.has_method("set_terrain_collision"):
			body.set_terrain_collision(true)
