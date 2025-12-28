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

func get_save_state() -> Dictionary:
	return { "current_health": current_health }

func apply_save_state(state: Dictionary) -> void:
	if state.has("current_health"):
		current_health = float(state["current_health"])
		# Clamp just in case config changed
		current_health = clampf(current_health, 0.0, max_health)
		# Notify listeners (like UI bars) that value loaded
		health_changed.emit(current_health, max_health)
