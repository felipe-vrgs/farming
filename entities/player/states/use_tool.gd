extends State

var _elapsed: float = 0.0
var _did_apply: bool = false
var _target_cell: Variant = null

func enter() -> void:
	_elapsed = 0.0
	_did_apply = false
	if parent == null:
		return

	# Stop movement for the tool action.
	parent.velocity = Vector2.ZERO

	# Player will append the facing suffix (left/right/front/back).
	# Here we emit only the tool base prefix (e.g. "hoe", "water", "axe").
	var anim_base := _compute_tool_animation_base()
	if not String(anim_base).is_empty():
		animation_change_requested.emit(anim_base)
		_sync_animation_speed(anim_base)

	# Cache the target cell at the start of the animation.
	# We'll apply the tool half-way through use_duration.
	_target_cell = parent.interactivity_manager.get_front_cell(parent)

func exit() -> void:
	if parent != null and parent.animated_sprite != null:
		parent.animated_sprite.speed_scale = 1.0

func process_input(event: InputEvent) -> StringName:
	# Ignore re-trigger while already using a tool.
	if parent == null || parent.player_input_config == null:
		return PlayerStateNames.NONE
	if event.is_action_pressed(parent.player_input_config.action_interact):
		return PlayerStateNames.NONE
	return PlayerStateNames.NONE

func process_physics(_delta: float) -> StringName:
	# Keep player still during use.
	if parent != null:
		parent.velocity = Vector2.ZERO
	return PlayerStateNames.NONE

func process_frame(delta: float) -> StringName:
	if parent == null or parent.equipped_tool == null:
		return PlayerStateNames.IDLE

	_elapsed += delta

	# Apply tool at half-way point, if we have a valid target cell.
	if not _did_apply and _target_cell != null:
		var half := parent.equipped_tool.use_duration * 0.5
		if _elapsed >= half:
			_did_apply = true
			parent.equipped_tool.try_use(parent, _target_cell as Vector2i)

	if _elapsed < parent.equipped_tool.use_duration:
		return PlayerStateNames.NONE

	# After tool use, return to movement states depending on input.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		return PlayerStateNames.IDLE
	return PlayerStateNames.WALK

func _compute_tool_animation_base() -> StringName:
	if parent == null or parent.equipped_tool == null:
		return &""

	var prefix := parent.equipped_tool.animation_prefix
	if String(prefix).is_empty():
		return &""
	return prefix

func _sync_animation_speed(anim_base: StringName) -> void:
	if parent == null or parent.equipped_tool == null or parent.animated_sprite == null:
		return

	# Reconstruct the full animation name to check its frame count
	var dir_suffix := "front"
	if parent.has_method("_direction_suffix"):
		dir_suffix = parent._direction_suffix(parent.interactivity_manager.facing_dir)

	var anim_full := StringName(str(anim_base, "_", dir_suffix))
	var frames := parent.animated_sprite.sprite_frames

	# Safety check: if the specific directional animation doesn't exist, maybe it uses the base name?
	if frames == null:
		return

	if not frames.has_animation(anim_full):
		# Fallback to base if directional is missing (legacy support)
		if frames.has_animation(anim_base):
			anim_full = anim_base
		else:
			return

	var frame_count := frames.get_frame_count(anim_full)
	var fps := frames.get_animation_speed(anim_full)

	# Avoid division by zero
	if fps <= 0 or parent.equipped_tool.use_duration <= 0:
		return

	var default_duration := float(frame_count) / fps

	# scale = default_duration / target_duration
	# Example: Anim is 0.5s. Tool is 1.0s. Scale = 0.5 (play at half speed).
	parent.animated_sprite.speed_scale = default_duration / parent.equipped_tool.use_duration
