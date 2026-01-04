class_name PlayerBalanceConfig
extends StatsConfig

# General
@export var move_speed: float = 100.0
@export var acceleration: float = 800.0
@export var friction: float = 800.0


func _init() -> void:
	max_health = 100.0
	max_mana = 100.0
	health_regen_per_second = 0.5
	mana_regen_per_second = 1.0
