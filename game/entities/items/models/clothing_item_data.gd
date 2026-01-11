class_name ClothingItemData
extends ItemData

## ClothingItemData
## Wearable item that maps onto the modular character sprite slots.
##
## `slot` should match one of the EquipmentSlots constants (e.g. &"shirt", &"pants").
## `variant` should match the generated SpriteFrames variant name (e.g. &"red_blue", &"brown").

@export var slot: StringName = &""
@export var variant: StringName = &""
