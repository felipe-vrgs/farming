extends Node2D

## Damage taken per axe hit.
@export var hit_damage: float = 25.0
@export var hit_sound: AudioStream = preload("res://assets/sounds/tools/chop.ogg")

@onready var health_component: HealthComponent = $HealthComponent

func on_interact(tool_data: ToolData, _cell: Vector2i = Vector2i.ZERO) -> bool:
	if tool_data.action_kind == Enums.ToolActionKind.AXE:
		health_component.take_damage(hit_damage)
		if hit_sound:
			SFXManager.play(hit_sound, global_position)
		return true

	return false
