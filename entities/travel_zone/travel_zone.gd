class_name TravelZone
extends Area2D

@export var target_level_id: Enums.Levels = Enums.Levels.NONE
@export var target_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE
@export var trigger_kind: Enums.AgentKind = Enums.AgentKind.PLAYER

func _ready() -> void:
	# Disable monitoring briefly to prevent immediate re-triggering upon spawn
	monitoring = false
	await get_tree().create_timer(1.0).timeout
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _matches_trigger_kind(body):
		call_deferred("_travel", body)

func _matches_trigger_kind(body: Node) -> bool:
	if body == null:
		return false

	# Preferred: AgentComponent contract (works for Player + NPCs).
	var ac := ComponentFinder.find_component_in_group(body, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		return int((ac as AgentComponent).kind) == int(trigger_kind)

	# Back-compat: Player nodes currently add themselves to group "player".
	return trigger_kind == Enums.AgentKind.PLAYER and body.is_in_group("player")

func _travel(agent: Node) -> void:
	if target_level_id == Enums.Levels.NONE:
		return

	# Player has input; NPCs typically don't.
	if agent != null and agent.has_method("set_input_enabled"):
		agent.call("set_input_enabled", false)

	if EventBus != null:
		EventBus.travel_requested.emit(agent, int(target_level_id), int(target_spawn_id))
