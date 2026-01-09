@tool
extends DialogicEvent

## Turn an agent (by id) to face toward a world position.
## - Updates the runtime node (if spawned) via CutsceneActorComponent.
## - Optionally writes facing_dir back into the AgentRecord (so future spawns keep it).

var agent_id: String = "player"
var pos: Vector2 = Vector2.ZERO
var refresh_idle: bool = true
var persist_to_record: bool = true

func _execute() -> void:
	if String(agent_id).is_empty():
		push_warning("FacePos: agent_id is empty.")
		finish()
		return

	var facing := Vector2.ZERO

	# Prefer runtime node as the source for the direction.
	if Runtime != null and Runtime.has_method("find_agent_by_id"):
		var node := Runtime.find_agent_by_id(StringName(agent_id))
		if node is Node2D:
			var v := pos - (node as Node2D).global_position
			if v.length() >= 0.001:
				facing = _quantize_to_cardinal(v)

			var comp_any := ComponentFinder.find_component_in_group(node, Groups.CUTSCENE_ACTOR_COMPONENTS)
			var comp := comp_any as CutsceneActorComponent
			if comp != null:
				comp.face_toward(pos, refresh_idle)

	# Fallback: if the node isn't spawned, try to infer direction from the record position.
	if facing == Vector2.ZERO and persist_to_record:
		if AgentBrain == null or AgentBrain.registry == null:
			# Can't infer without the agent registry.
			finish()
			return
		var effective_id := _resolve_effective_record_id(StringName(agent_id))
		var rec_any = AgentBrain.registry.get_record(effective_id)
		var rec := rec_any as AgentRecord
		if rec != null:
			var v2 := pos - rec.last_world_pos
			if v2.length() >= 0.001:
				facing = _quantize_to_cardinal(v2)

	# Persist record facing if requested and we have a non-zero direction.
	if persist_to_record and facing != Vector2.ZERO:
		if AgentBrain == null or AgentBrain.registry == null:
			# Can't persist without the agent registry.
			finish()
			return
		var effective_id2 := _resolve_effective_record_id(StringName(agent_id))
		var rec_any2 = AgentBrain.registry.get_record(effective_id2)
		var rec2 := rec_any2 as AgentRecord
		if rec2 != null:
			rec2.facing_dir = facing
			AgentBrain.registry.upsert_record(rec2)

	finish()


func _resolve_effective_record_id(id: StringName) -> StringName:
	# Handle older saves where the player record id is not literally "player".
	if id != &"player":
		return id
	if AgentBrain == null or AgentBrain.registry == null:
		return id
	var direct = AgentBrain.registry.get_record(&"player")
	if direct is AgentRecord:
		return &"player"
	for r in AgentBrain.registry.list_records():
		if r != null and r.kind == Enums.AgentKind.PLAYER:
			return r.agent_id
	return id


func _quantize_to_cardinal(v: Vector2) -> Vector2:
	if abs(v.x) >= abs(v.y):
		return Vector2.RIGHT if v.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y >= 0.0 else Vector2.UP


func _init() -> void:
	event_name = "Face Position"
	set_default_color("Color7")
	event_category = "Agent"
	event_sorting_index = 3


func get_shortcode() -> String:
	return "cutscene_face_pos"


func get_shortcode_parameters() -> Dictionary:
	return {
		"agent_id": {"property": "agent_id", "default": "player"},
		"pos": {"property": "pos", "default": Vector2.ZERO},
		"refresh": {"property": "refresh_idle", "default": true},
		"persist": {"property": "persist_to_record", "default": true},
	}


func build_event_editor() -> void:
	add_header_edit("agent_id", ValueType.DYNAMIC_OPTIONS, {
		"left_text":"Face agent",
		"autofocus":true,
		"placeholder":"Agent id",
		"mode": 0, # PURE_STRING
		"suggestions_func": CutsceneOptions.get_agent_id_suggestions,
	})
	add_header_label("toward")
	add_header_edit("pos", ValueType.VECTOR2, {"placeholder":"World position (x, y)"})

	add_body_edit("refresh_idle", ValueType.BOOL, {"left_text":"Refresh idle visuals:"})
	add_body_edit("persist_to_record", ValueType.BOOL, {"left_text":"Persist to AgentRecord:"})
