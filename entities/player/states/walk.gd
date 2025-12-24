extends State

const FOOTSTEP_INTERVAL: float = 0.35

# Preload footstep sounds
var footsteps: Array[AudioStream] = [
	preload("res://assets/sounds/player/footstep00.ogg"),
	preload("res://assets/sounds/player/footstep01.ogg"),
	preload("res://assets/sounds/player/footstep02.ogg"),
	preload("res://assets/sounds/player/footstep03.ogg"),
	preload("res://assets/sounds/player/footstep04.ogg"),
	preload("res://assets/sounds/player/footstep05.ogg"),
	preload("res://assets/sounds/player/footstep06.ogg"),
	preload("res://assets/sounds/player/footstep07.ogg"),
	preload("res://assets/sounds/player/footstep08.ogg"),
	preload("res://assets/sounds/player/footstep09.ogg"),
]
var _footstep_timer: float = 0.0

func enter() -> void:
	super.enter()
	_footstep_timer = 0.0

func process_input(event: InputEvent) -> StringName:
	if parent and parent.player_input_config:
		if event.is_action_pressed(parent.player_input_config.action_interact):
			return PlayerStateNames.TOOL_CHARGING
	return PlayerStateNames.NONE

func process_physics(delta: float) -> StringName:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		return PlayerStateNames.IDLE

	if parent and player_balance_config:
		var target_velocity = input_dir * player_balance_config.move_speed
		var acceleration = player_balance_config.acceleration * delta
		parent.velocity = parent.velocity.move_toward(target_velocity, acceleration)

		update_animation(input_dir)
		play_footstep(delta)

	return PlayerStateNames.NONE

func play_footstep(delta: float) -> void:
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = FOOTSTEP_INTERVAL
		if parent and parent.audio_player:
			var idx = randi() % footsteps.size()
			parent.audio_player.stream = footsteps[idx]
			parent.audio_player.play()

func update_animation(_input_dir: Vector2) -> void:
	if parent == null or parent.animated_sprite == null:
		return

	# Player will append the facing suffix (left/right/front/back).
	# We keep direction tracking in `InteractivityManager`, so states only choose the base.
	animation_change_requested.emit(&"move")
