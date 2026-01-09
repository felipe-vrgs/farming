@tool
extends DialogicEvent

## Camera controls for cutscenes (best-effort).
##
## This operates on the player's `Camera2D` (Player/Camera2D) since the game uses a
## player-owned camera.
##
## Supports:
## - Pan camera to a world position (optionally "free camera" by setting top_level=true)
## - Set camera offset
## - Set camera zoom
## - Reset camera back to its pre-cutscene defaults (captured on first use)

const _CAMERA_DEFAULTS_META := &"dialogic_additions_camera_defaults"

## What to do. Stored as a string so `.dtl` shorthand is readable.
## Supported values: "pan", "offset", "zoom", "reset"
var action: String = "pan"

var pos: Vector2 = Vector2.ZERO
var offset: Vector2 = Vector2.ZERO
var zoom: Vector2 = Vector2.ONE

var duration: float = 0.0
var wait: bool = true
var free_camera: bool = true

var _tween: Tween = null


func _execute() -> void:
	var cam := _get_player_camera()
	if cam == null:
		push_warning("CameraControl: Could not find Player/Camera2D.")
		finish()
		return

	_ensure_camera_defaults(cam)

	# Cancel any previous tween started by this event instance.
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null

	match action:
		"pan":
			cam.top_level = free_camera
			_run_tween(cam, NodePath("global_position"), pos)
			return

		"offset":
			_run_tween(cam, NodePath("offset"), offset)
			return

		"zoom":
			# Guard against invalid zoom values.
			var z := zoom
			z.x = maxf(0.001, z.x)
			z.y = maxf(0.001, z.y)
			_run_tween(cam, NodePath("zoom"), z)
			return

		"reset":
			_apply_camera_defaults(cam)
			finish()
			return

	finish()


func _run_tween(target: Object, prop: NodePath, value: Variant) -> void:
	var d := maxf(0.0, float(duration))
	if d <= 0.0 or dialogic == null:
		target.set_indexed(prop, value)
		finish()
		return

	_tween = dialogic.get_tree().create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(target, prop, value, d)

	if wait:
		dialogic.current_state = dialogic.States.WAITING
		_tween.finished.connect(_on_tween_finished)
		return

	# Fire-and-forget: do not block the timeline.
	finish()


func _on_tween_finished() -> void:
	if dialogic != null:
		dialogic.current_state = dialogic.States.IDLE
	finish()


func _get_player_camera() -> Camera2D:
	var player: Node2D = null
	if Runtime != null and Runtime.has_method("find_agent_by_id"):
		player = Runtime.find_agent_by_id(&"player")
	if player == null and dialogic != null and dialogic.get_tree() != null:
		player = dialogic.get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D
	if player == null:
		return null

	var cam := player.get_node_or_null(NodePath("Camera2D")) as Camera2D
	return cam


func _ensure_camera_defaults(cam: Camera2D) -> void:
	if cam == null:
		return
	if cam.has_meta(_CAMERA_DEFAULTS_META):
		return
	cam.set_meta(
		_CAMERA_DEFAULTS_META,
		{
			"top_level": cam.top_level,
			"position": cam.position,
			"offset": cam.offset,
			"zoom": cam.zoom,
			"position_smoothing_enabled": cam.position_smoothing_enabled,
			"position_smoothing_speed": cam.position_smoothing_speed,
		}
	)


func _apply_camera_defaults(cam: Camera2D) -> void:
	if cam == null:
		return
	if not cam.has_meta(_CAMERA_DEFAULTS_META):
		return
	var d_any: Variant = cam.get_meta(_CAMERA_DEFAULTS_META)
	if not (d_any is Dictionary):
		return
	var d: Dictionary = d_any

	if d.has("top_level"):
		cam.top_level = bool(d["top_level"])
	if d.has("position"):
		cam.position = d["position"]
	if d.has("offset"):
		cam.offset = d["offset"]
	if d.has("zoom"):
		cam.zoom = d["zoom"]
	if d.has("position_smoothing_enabled"):
		cam.position_smoothing_enabled = bool(d["position_smoothing_enabled"])
	if d.has("position_smoothing_speed"):
		cam.position_smoothing_speed = float(d["position_smoothing_speed"])


func _init() -> void:
	event_name = "Camera Control"
	set_default_color("Color7")
	event_category = "Camera"
	event_sorting_index = 0


func get_shortcode() -> String:
	return "cutscene_camera_control"


func get_shortcode_parameters() -> Dictionary:
	return {
		"action": {"property": "action", "default": "pan"},
		"pos": {"property": "pos", "default": Vector2.ZERO},
		"offset": {"property": "offset", "default": Vector2.ZERO},
		"zoom": {"property": "zoom", "default": Vector2.ONE},
		"duration": {"property": "duration", "default": 0.0},
		"wait": {"property": "wait", "default": true},
		"free": {"property": "free_camera", "default": true},
	}


func build_event_editor() -> void:
	add_header_label("Camera")
	add_header_edit("action", ValueType.FIXED_OPTIONS, {
		"options": [
			{"label":"Pan to position", "value": "pan"},
			{"label":"Set offset", "value": "offset"},
			{"label":"Set zoom", "value": "zoom"},
			{"label":"Reset", "value": "reset"},
		],
	})

	add_body_edit("pos", ValueType.VECTOR2, {"left_text":"Target pos:"}, "action == 'pan'")
	add_body_edit(
		"free_camera",
		ValueType.BOOL,
		{"left_text":"Free camera (top_level):"},
		"action == 'pan'"
	)

	add_body_edit("offset", ValueType.VECTOR2, {"left_text":"Offset:"}, "action == 'offset'")
	add_body_edit("zoom", ValueType.VECTOR2, {"left_text":"Zoom:"}, "action == 'zoom'")

	add_body_edit(
		"duration",
		ValueType.NUMBER,
		{"left_text":"Tween time (s):", "min": 0.0},
		"action != 'reset'"
	)
	add_body_edit("wait", ValueType.BOOL, {"left_text":"Wait for tween:"}, "action != 'reset'")
