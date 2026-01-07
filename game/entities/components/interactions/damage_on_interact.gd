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

	var use_hit_pos := ctx != null and ctx.hit_world_pos != Vector2.ZERO
	# Use call() to avoid static signature issues across duplicate scripts.
	health_component.call("take_damage", damage, ctx.hit_world_pos, use_hit_pos)
	if hit_sound:
		SFXManager.play_effect(hit_sound, _parent.global_position)
	return true
