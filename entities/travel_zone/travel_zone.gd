class_name TravelZone
extends Area2D

@export var target_level_id: Enums.Levels = Enums.Levels.NONE
@export var target_spawn_id: Enums.SpawnId = Enums.SpawnId.NONE

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_warn_on_spawn_marker_overlap()

func _warn_on_spawn_marker_overlap() -> void:
	# Best-effort authoring safety: warn if a spawn marker sits inside this travel zone.
	# Overlap can cause immediate bounce-back travel unless cooldowns are perfect.
	var cs := get_node_or_null(NodePath("CollisionShape2D"))
	if not (cs is CollisionShape2D):
		return
	var shape := (cs as CollisionShape2D).shape
	if shape == null:
		return

	# Find a likely level root (TravelZones are always inside a level scene).
	var level_root: Node = self
	while level_root.get_parent() != null:
		level_root = level_root.get_parent()
		# Heuristic: stop at the scene root (parent == current_scene).
		if level_root.get_parent() == get_tree().current_scene:
			break

	for n in get_tree().get_nodes_in_group(Groups.SPAWN_MARKERS):
		if not (n is Marker2D):
			continue
		if not level_root.is_ancestor_of(n):
			continue

		var sidv = (n as Node).get("spawn_id")
		if typeof(sidv) != TYPE_INT:
			continue

		var p: Vector2 = (n as Marker2D).global_position
		if _shape_contains_world_point(shape, (cs as CollisionShape2D).global_transform, p):
			push_warning(
				"TravelZone overlap: SpawnMarker '%s' (spawn_id=%s) is inside TravelZone '%s'." % [
					str((n as Node).get_path()),
					str(int(sidv)),
					str(get_path()),
				]
			)

static func _shape_contains_world_point(
	shape: Shape2D,
	shape_global_xform: Transform2D,
	world_point: Vector2
) -> bool:
	if shape == null:
		return false
	# Transform point into shape-local space.
	var local := shape_global_xform.affine_inverse() * world_point
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		return abs(local.x) <= half.x and abs(local.y) <= half.y
	if shape is CircleShape2D:
		return local.length() <= float((shape as CircleShape2D).radius)
	return false

func _on_body_entered(body: Node) -> void:
	if _matches_trigger_kind(body):
		call_deferred("_travel", body)

func _matches_trigger_kind(body: Node) -> bool:
	if body == null:
		return false

	var ac := ComponentFinder.find_component_in_group(body, Groups.AGENT_COMPONENTS)
	if ac is AgentComponent:
		return true

	return false

func _travel(agent: Node) -> void:
	if target_level_id == Enums.Levels.NONE:
		return

	# Agent-level cooldown (prevents immediate bounce-back on spawn overlap).
	if AgentRegistry != null:
		# Use the registry identity (not the component's default value) to avoid mismatches
		# like agent_id="npc" vs record agent_id="frieren" during spawn/config timing.
		var rec := AgentRegistry.ensure_agent_registered_from_node(agent) as AgentRecord
		var rid: StringName = rec.agent_id if rec != null else &""
		if not AgentRegistry.is_travel_allowed_now(rid):
			return

	# Player has input; NPCs typically don't.
	if agent != null and agent.has_method("set_input_enabled"):
		agent.call("set_input_enabled", false)

	if EventBus != null:
		EventBus.travel_requested.emit(agent, int(target_level_id), int(target_spawn_id))
