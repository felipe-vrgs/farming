class_name DamageOnInteract
extends InteractableComponent

@export var required_action_kind: Enums.ToolActionKind = Enums.ToolActionKind.AXE
@export var damage: float = 25.0
@export var hit_sound: AudioStream = preload("res://assets/sounds/tools/chop.ogg")
@export var health_component: HealthComponent = null

var _parent: Node = null

func _ready() -> void:
	_parent = get_parent()

func try_interact(ctx: InteractionContext) -> bool:
	if !ctx.is_tool(required_action_kind):
		return false
	if health_component == null:
		return false

	health_component.take_damage(damage)
	if hit_sound:
		SFXManager.play(hit_sound, _parent.global_position)
	return true

