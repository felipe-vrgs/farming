class_name HealthComponent
extends Node2D

## Signal emitted when health changes.
signal health_changed(current: float, max: float)
## Signal emitted when health reaches zero.
signal depleted


@export var max_health: float = 100.0

var _progress_bar: ProgressBar

@onready var current_health: float = max_health

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.max_value = max_health
	_progress_bar.value = current_health

	# Basic styling to make it look like a health bar
	_progress_bar.size = Vector2(32, 4)
	_progress_bar.position = Vector2(-16, -48) # Positioned above the entity

	# Use a simple theme override for colors if we don't have a theme
	_progress_bar.add_theme_color_override("font_color", Color.WHITE)

	_progress_bar.hide()
	add_child(_progress_bar)

## Apply damage to this component.
func take_damage(amount: float) -> void:
	if current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	_progress_bar.value = current_health
	_progress_bar.show()

	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		depleted.emit()

## Reset health to max.
func heal_full() -> void:
	current_health = max_health
	_progress_bar.value = current_health
	_progress_bar.hide()
	health_changed.emit(current_health, max_health)

