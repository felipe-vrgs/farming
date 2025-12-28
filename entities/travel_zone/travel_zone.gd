class_name TravelZone
extends Area2D

@export var target_level_id: StringName = &""

func _ready() -> void:
	# Disable monitoring briefly to prevent immediate re-triggering upon spawn
	monitoring = false
	await get_tree().create_timer(1.0).timeout
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Check group "player" which is safer than class checking if class_name not loaded
	if body.is_in_group("player"):
		call_deferred("_travel", body)

func _travel(player: Node) -> void:
	if target_level_id.is_empty():
		return

	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	GameManager.travel_to_level(target_level_id)
