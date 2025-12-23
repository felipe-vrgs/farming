class_name WorldItem
extends Area2D

@export var item_data: ItemData
@export var count: int = 1

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if item_data:
		sprite.texture = item_data.icon

	body_entered.connect(_on_body_entered)

	# Small animation to "pop" out
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).from(Vector2.ZERO)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.inventory:
			var remaining = body.inventory.add_item(item_data, count)
			if remaining == 0:
				# TODO: Play pickup sound/VFX
				queue_free()
			else:
				count = remaining

