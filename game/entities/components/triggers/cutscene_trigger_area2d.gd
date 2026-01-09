class_name CutsceneTriggerArea2D
extends Area2D

## Area2D trigger that starts a cutscene when the player enters.
## Supports once-only behavior persisted through SaveComponent.
##
## Persistence:
## - Add a SaveComponent with properties=["has_triggered"] to save the fired state.
## - Add a PersistentEntityComponent so authored (level-placed) triggers reconcile on load.

@export var cutscene_id: StringName = &""
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
	if String(cutscene_id).is_empty():
		return
	if EventBus != null:
		EventBus.cutscene_start_requested.emit(cutscene_id, body)

	if once:
		has_triggered = true
