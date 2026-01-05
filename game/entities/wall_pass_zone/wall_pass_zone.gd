@tool
class_name WallPassZone
extends Area2D

## While inside this zone, player can pass through terrain (walls/cliffs).
## Used for stairs and similar transitions.


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if Engine.is_editor_hint():
		return

	if body is Player:
		(body as Player).set_terrain_collision(false)


func _on_body_exited(body: Node) -> void:
	if Engine.is_editor_hint():
		return

	if body is Player:
		(body as Player).set_terrain_collision(true)
