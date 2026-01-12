@tool
extends DialogicEvent

## Turn an agent (by id) to face a cardinal direction.
## - Updates the runtime node (if spawned) via CutsceneActorComponent.
## - Optionally writes facing_dir back into the AgentRecord (so future spawns keep it).
var agent_id: String = "player"
## Supported values: "left", "right", "front", "back". Empty = use `pos` (legacy).
var facing_dir: String = ""

var refresh_idle: bool = true
var persist_to_record: bool = true

func _execute() -> void:
	if String(agent_id).is_empty():
		push_warning("FacePos: agent_id is empty.")
		finish()
		return

	var facing := _resolve_facing_override()
	if facing == Vector2.ZERO:
		finish()
		return

	# Prefer runtime node as the target for visuals.
	if Runtime != null and Runtime.has_method("find_agent_by_id"):
		var node2 := Runtime.find_agent_by_id(StringName(agent_id))
		if node2 is Node2D:
			var comp_any2 := ComponentFinder.find_component_in_group(
				node2, Groups.CUTSCENE_ACTOR_COMPONENTS
			)
			var comp2 := comp_any2 as CutsceneActorComponent
			if comp2 != null:
				# Use face_toward so we get the normal idle refresh behavior.
				comp2.face_toward(
					(node2 as Node2D).global_position + (facing * 8.0),
					refresh_idle
				)

	# Persist record facing if requested and we have a non-zero direction.
	if persist_to_record:
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

func _resolve_facing_override() -> Vector2:
	var s := facing_dir.strip_edges().to_lower()
	match s:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"front", "down":
			return Vector2.DOWN
		"back", "up":
			return Vector2.UP
		"", "none", "keep":
			return Vector2.ZERO
		_:
			return Vector2.ZERO


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
	event_name = "Face"
	set_default_color("Color7")
	event_category = "Agent"
	event_sorting_index = 3


func get_shortcode() -> String:
	return "cutscene_face_pos"


func get_shortcode_parameters() -> Dictionary:
	return {
		"agent_id": {"property": "agent_id", "default": "player"},
		"facing": {"property": "facing_dir", "default": ""},
		# Legacy:
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
	add_body_edit("facing_dir", ValueType.FIXED_OPTIONS, {
		"left_text":"Facing:",
		"options": CutsceneOptions.facing_fixed_options(),
	})

	add_body_edit("refresh_idle", ValueType.BOOL, {"left_text":"Refresh idle visuals:"})
	add_body_edit("persist_to_record", ValueType.BOOL, {"left_text":"Persist to AgentRecord:"})
