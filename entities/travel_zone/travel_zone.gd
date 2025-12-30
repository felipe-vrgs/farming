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
	var ac = body.get_node_or_null(NodePath("AgentComponent"))
	if ac == null:
		ac = body.get_node_or_null(NodePath("Components/AgentComponent"))
	if ac != null:
		var kind_v = ac.get("kind")
		if typeof(kind_v) == TYPE_INT:
			return int(kind_v) == int(trigger_kind)

	# Back-compat: Player nodes currently add themselves to group "player".
	return trigger_kind == Enums.AgentKind.PLAYER and body.is_in_group("player")

func _travel(player: Node) -> void:
	if target_level_id == Enums.Levels.NONE:
		return

	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	GameManager.travel_to_level(target_level_id, target_spawn_id)
