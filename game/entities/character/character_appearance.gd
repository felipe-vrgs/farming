class_name CharacterAppearance
extends Resource

## Which variant to use per slot. Each variant is expected to have a generated SpriteFrames
## at: res://assets/characters/generated/<slot>/<variant>.tres
##
## Slot folders under res://assets/characters/base/<action>/<slot>/<variant>.png

@export_group("Body")
@export var legs_variant: StringName = &"default"
@export var torso_variant: StringName = &"default"

@export_group("Clothes")
@export var pants_variant: StringName = &""
@export var shirt_variant: StringName = &""

@export_group("Head")
@export var face_variant: StringName = &"male"
@export var hair_variant: StringName = &"mohawk"

@export_group("Colors")
@export var skin_color: Color = Color(0.91, 0.74, 0.62, 1.0)
@export var eye_color: Color = Color(0.25, 0.55, 1.0, 1.0)

@export_group("Overlays")
@export var hands_top_variant: StringName = &"default"
