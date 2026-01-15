@tool
extends SpeakerPortraitTextboxLayerBase

@export var portrait_container_path: NodePath = NodePath(
	"Anchor/PortraitPanel/DialogicNode_PortraitContainer"
)
@export var panel_frame_path: NodePath = NodePath("Anchor/PanelFrame")
@export var panel_target_position: Vector2 = Vector2.ZERO
@export var panel_target_size: Vector2 = Vector2.ZERO
@export var portrait_panel_target_position: Vector2 = Vector2.ZERO
@export var portrait_panel_target_size: Vector2 = Vector2.ZERO

var _portrait_base_position: Vector2 = Vector2.ZERO
var _portrait_base_rotation: float = 0.0
var _portrait_base_scale: Vector2 = Vector2.ONE
var _portrait_effect_tween: Tween = null
var _panel_saved_position: Vector2 = Vector2.ZERO
var _panel_saved_size: Vector2 = Vector2.ZERO
var _portrait_panel_saved_position: Vector2 = Vector2.ZERO
var _portrait_panel_saved_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	super()
	_cache_layout_defaults()
	_bind_portrait_container()
	_cache_portrait_base()


func _cache_layout_defaults() -> void:
	var panel := %Panel as Control
	if panel != null:
		_panel_saved_position = panel_target_position
		_panel_saved_size = panel_target_size
		if _panel_saved_position == Vector2.ZERO:
			_panel_saved_position = panel.position
		if _panel_saved_size == Vector2.ZERO:
			_panel_saved_size = panel.size
	var portrait_panel := %PortraitPanel as Control
	if portrait_panel != null:
		_portrait_panel_saved_position = portrait_panel_target_position
		_portrait_panel_saved_size = portrait_panel_target_size
		if _portrait_panel_saved_position == Vector2.ZERO:
			_portrait_panel_saved_position = portrait_panel.position
		if _portrait_panel_saved_size == Vector2.ZERO:
			_portrait_panel_saved_size = portrait_panel.size


func _apply_export_overrides() -> void:
	super()
	var panel := %Panel as Control
	var frame := get_node_or_null(panel_frame_path) as Control
	if panel == null:
		return
	if _panel_saved_size != Vector2.ZERO:
		panel.size = _panel_saved_size
		panel.position = _panel_saved_position
	var portrait_panel := %PortraitPanel as Control
	if portrait_panel != null and _portrait_panel_saved_size != Vector2.ZERO:
		portrait_panel.size = _portrait_panel_saved_size
		portrait_panel.position = _portrait_panel_saved_position
	if frame != null:
		frame.size = panel.size + Vector2(6, 6)
		frame.position = panel.position - Vector2(3, 3)


func _bind_portrait_container() -> void:
	var container := _get_portrait_container()
	if container == null:
		return
	if not container.child_entered_tree.is_connected(_on_portrait_child_changed):
		container.child_entered_tree.connect(_on_portrait_child_changed)
	if not container.child_exiting_tree.is_connected(_on_portrait_child_changed):
		container.child_exiting_tree.connect(_on_portrait_child_changed)


func _on_portrait_child_changed(_child: Node) -> void:
	_cache_portrait_base()


func _get_portrait_container() -> Node:
	return get_node_or_null(portrait_container_path)


func _get_portrait_target() -> Node:
	var container := _get_portrait_container()
	if container == null:
		return null
	for child in container.get_children():
		if child is Node2D:
			return child
	return container


func _cache_portrait_base() -> void:
	var target := _get_portrait_target()
	if target == null:
		return
	_portrait_base_position = target.position
	_portrait_base_rotation = target.rotation
	if "scale" in target:
		_portrait_base_scale = target.scale
	else:
		_portrait_base_scale = Vector2.ONE


func _clear_portrait_tween() -> void:
	if _portrait_effect_tween != null and is_instance_valid(_portrait_effect_tween):
		_portrait_effect_tween.kill()
	_portrait_effect_tween = null


func reset_portrait_effects() -> void:
	var target := _get_portrait_target()
	if target == null:
		return
	_clear_portrait_tween()
	target.position = _portrait_base_position
	target.rotation = _portrait_base_rotation
	if "scale" in target:
		target.scale = _portrait_base_scale


func play_portrait_effect(effect: String, duration: float = 0.25, intensity: float = 1.0) -> void:
	var target := _get_portrait_target()
	if target == null:
		return

	_clear_portrait_tween()
	_cache_portrait_base()

	duration = max(duration, 0.0)
	intensity = max(intensity, 0.0)

	if effect == "reset":
		target.position = _portrait_base_position
		target.rotation = _portrait_base_rotation
		if "scale" in target:
			target.scale = _portrait_base_scale
		return

	if duration == 0.0:
		duration = 0.01

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	_portrait_effect_tween = tween

	match effect:
		"wiggle":
			var angle := deg_to_rad(6.0) * intensity
			tween.tween_property(
				target, "rotation", _portrait_base_rotation + angle, duration * 0.25
			)
			tween.tween_property(
				target, "rotation", _portrait_base_rotation - angle, duration * 0.5
			)
			tween.tween_property(target, "rotation", _portrait_base_rotation, duration * 0.25)
		"bob":
			var offset := Vector2(0.0, -6.0 * intensity)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.5
			)
			tween.tween_property(target, "position", _portrait_base_position, duration * 0.5)
		"nudge_up":
			var offset := Vector2(0.0, -8.0 * intensity)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.5
			)
			tween.tween_property(target, "position", _portrait_base_position, duration * 0.5)
		"nudge_down":
			var offset := Vector2(0.0, 8.0 * intensity)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.5
			)
			tween.tween_property(target, "position", _portrait_base_position, duration * 0.5)
		"nudge_left":
			var offset := Vector2(-8.0 * intensity, 0.0)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.5
			)
			tween.tween_property(target, "position", _portrait_base_position, duration * 0.5)
		"nudge_right":
			var offset := Vector2(8.0 * intensity, 0.0)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.5
			)
			tween.tween_property(target, "position", _portrait_base_position, duration * 0.5)
		"shake":
			var offset := Vector2(6.0 * intensity, 0.0)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.2
			)
			tween.tween_property(
				target, "position", _portrait_base_position - offset, duration * 0.2
			)
			tween.tween_property(
				target, "position", _portrait_base_position + offset, duration * 0.2
			)
			tween.tween_property(target, "position", _portrait_base_position, duration * 0.4)
		"pulse":
			if "scale" in target:
				var scale_up := _portrait_base_scale * (1.0 + (0.05 * intensity))
				tween.tween_property(target, "scale", scale_up, duration * 0.5)
				tween.tween_property(target, "scale", _portrait_base_scale, duration * 0.5)
			else:
				tween.tween_property(target, "position", _portrait_base_position, duration)
		_:
			tween.tween_property(target, "position", _portrait_base_position, duration)

	tween.finished.connect(
		func() -> void:
			if target == null or not is_instance_valid(target):
				return
			target.position = _portrait_base_position
			target.rotation = _portrait_base_rotation
			if "scale" in target:
				target.scale = _portrait_base_scale
	)
