class_name NightEndTriggerArea2D
extends Area2D

## Area2D trigger that ends night mode when the player enters.
## Supports once-only behavior persisted through SaveComponent.

@export var once: bool = true
@export var enabled: bool = true
@export var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not enabled:
		return
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group(Groups.PLAYER):
		return
	if once and has_triggered:
		return

	if EventBus != null:
		EventBus.night_exit_requested.emit(body)

	if once:
		has_triggered = true
