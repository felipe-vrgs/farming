class_name PlayerBalanceConfig
extends StatsConfig

# General
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 2000.0  # Increased for faster terminal velocity
@export var move_speed: float = 70.0  # Slightly reduced for more precision
@export var jump_speed: float = 360.0  # Increased for more forgiving, higher jumps
@export var crouch_speed_multiplier: float = 0.5
@export var air_control_acceleration: float = 750.0  # Reduced for less forgiving air control
@export var air_neutral_drag: float = 400.0
@export var input_buffer_duration: float = 0.10  # Reduced for tighter timing windows
@export var coyote_time: float = 0.08  # Reduced for more precise jump timing

# Ability
## Dash
@export var dash_cooldown: float = 3  # Increased cooldown for more strategic use
@export var dash_duration: float = 0.3  # Slightly shorter for more precision
@export var dash_activation_cost: float = 0  # Now costs mana - strategic resource management
@export var dash_speed_multiplier: float = 3.2  # Slightly faster for better feel
## Steel
@export var steel_activation_cost: float = 3.0  # Costs mana to activate
@export var steel_mana_drain_per_second: float = 8.0  # Increased drain - more expensive to maintain
@export var steel_gravity_multiplier: float = 4.5  # Even faster fall for strategic positioning
@export var steel_terminal_speed: float = 2200.0  # Faster terminal speed
## Glide
@export var glide_activation_cost: float = 10.0  # Costs mana to activate
@export var glide_mana_drain_per_second: float = 2.0  # Increased drain - can't glide forever
@export var glide_gravity_multiplier: float = 0.003  # Slightly less floaty for more control
@export var glide_oscillation_amplitude: float = 45.0  # Reduced oscillation
@export var glide_oscillation_frequency: float = 5.0  # Slightly faster oscillation
## Air Jump
@export var air_jump_mana_cost: float = 20.0
@export var air_jump_speed_multiplier: float = 1.05
## Wall Hug
@export var wall_hug_slide_speed: float = 55.0  # Slightly slower for more control
@export var wall_hug_stick_speed: float = 55.0
@export var wall_hug_min_normal_x: float = 0.75  # Slightly stricter angle requirement
@export var wall_jump_horizontal_speed: float = 200.0  # Increased for better wall jump feel
@export var wall_jump_vertical_multiplier: float = 1.1

# Skill
@export var skill_cooldown: float = 5.0
## Fireball
@export var fireball_speed: float = 300.0
@export var fireball_lifetime: float = 10.0
@export var fireball_damage: float = 20.0
@export var fireball_explosion_radius: float = 10.0
## Ice Wall
@export var ice_wall_health: int = 3
@export var ice_wall_lifetime: float = 4.0
## Water Spray
@export var water_spray_duration: float = 0.5
@export var water_spray_knockback: float = 250.0
@export var water_spray_damage: float = 10.0
@export var external_force_drag: float = 1200.0

func _init() -> void:
	health_regen_per_second = 0.5
	mana_regen_per_second = 0.5
	max_health = 100.0
	max_mana = 100.0