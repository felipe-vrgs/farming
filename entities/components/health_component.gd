class_name HealthComponent
extends Node2D

## Signal emitted when health changes.
signal health_changed(current: float, max: float)
## Signal emitted when health reaches zero.
signal depleted

@export var max_health: float = 100.0

@onready var current_health: float = max_health

## Apply damage to this component.
func take_damage(amount: float) -> void:
	if current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		depleted.emit()

## Reset health to max.
func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
