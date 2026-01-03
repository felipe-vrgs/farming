class_name TravelZone
extends Area2D

## Where to travel when entered (player only).
@export var target_spawn_point: SpawnPointData = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _matches_trigger_kind(body):
		call_deferred("_travel", body)

func _matches_trigger_kind(body: Node) -> bool:
	if body == null:
		return false

	return body.is_in_group(Groups.PLAYER)

func _travel(agent: Node) -> void:
	if target_spawn_point == null or not target_spawn_point.is_valid():
		return

	# Disable player input during travel
	if agent != null and agent.has_method("set_input_enabled"):
		agent.call("set_input_enabled", false)

	if Runtime != null and Runtime.scene_loader != null and Runtime.scene_loader.is_loading():
		await Runtime.scene_loader.loading_finished

	if EventBus != null:
		EventBus.travel_requested.emit(agent, target_spawn_point)
