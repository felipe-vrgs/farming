class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var description: String

## Economy (optional). Used by ShopMenu.
@export var buy_price: int = 1
@export var sell_price: int = 1
