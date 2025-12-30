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
	var ac := _find_component_in_group(body, &"agent_components")
	if ac is AgentComponent:
		return int((ac as AgentComponent).kind) == int(trigger_kind)

	# Back-compat: Player nodes currently add themselves to group "player".
	return trigger_kind == Enums.AgentKind.PLAYER and body.is_in_group("player")

func _travel(player: Node) -> void:
	if target_level_id == Enums.Levels.NONE:
		return

	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if EventBus != null:
		EventBus.travel_requested.emit(player, int(target_level_id), int(target_spawn_id))

static func _find_component_in_group(entity: Node, group_name: StringName) -> Node:
	if entity == null:
		return null

	for child in entity.get_children():
		if child is Node and (child as Node).is_in_group(group_name):
			return child as Node

	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		for child in (components as Node).get_children():
			if child is Node and (child as Node).is_in_group(group_name):
				return child as Node

	return null
