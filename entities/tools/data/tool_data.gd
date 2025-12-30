class_name ToolData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D
@export var action_kind: Enums.ToolActionKind = Enums.ToolActionKind.NONE
@export var use_duration: float = 0.2
@export var animation_prefix: StringName = &""

## Feedback settings
@export_group("Feedback")
@export var player_recoil: bool = false
@export var sound_charge: AudioStream
@export var sound_swing: AudioStream
@export var sound_success: AudioStream
@export var sound_fail: AudioStream
@export var has_charge: bool = false
@export var swish_type: Enums.ToolSwishType = Enums.ToolSwishType.NONE

## Generic dictionary for tool-specific data (e.g. seed plant_id)
var extra_data: Dictionary = {}

func try_use(cell: Vector2i) -> bool:
	var entities = WorldGrid.get_entities_at(cell)
	if entities.is_empty():
		return false

	for target in entities:
		if target.has_method("on_interact"):
			if target.on_interact(self, cell):
				return true
	return false
