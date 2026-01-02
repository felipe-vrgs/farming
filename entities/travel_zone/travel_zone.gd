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

	# Agent-level cooldown (prevents immediate bounce-back on spawn overlap).
	if AgentRegistry != null:
		var rec := AgentRegistry.ensure_agent_registered_from_node(agent) as AgentRecord
		var rid: StringName = rec.agent_id if rec != null else &""
		if not AgentRegistry.is_travel_allowed_now(rid):
			return

	# Disable player input during travel
	if agent != null and agent.has_method("set_input_enabled"):
		agent.call("set_input_enabled", false)

	if EventBus != null:
		EventBus.travel_requested.emit(agent, target_spawn_point)
