class_name TreeObstacle
extends Node2D

## Small draw-order trick to help sell "tool passes through the tree".
## When hit by an axe, we briefly push the trunk behind world entities so the axe swing can
## visibly cross over the trunk (reliable, no extra sprites needed).

@onready var _trunk: Sprite2D = $Visual/TrunkSprite2D

var _trunk_z_as_relative: bool = true
var _trunk_z_index: int = 0
var _trunk_tween: Tween = null


func _ready() -> void:
	if _trunk != null:
		_trunk_z_as_relative = _trunk.z_as_relative
		_trunk_z_index = _trunk.z_index


func on_tool_hit(ctx: InteractionContext) -> void:
	# Called opportunistically by DamageOnInteract when present.
	if ctx == null or not ctx.is_tool(Enums.ToolActionKind.AXE):
		return
	if _trunk == null or not is_instance_valid(_trunk):
		return

	# Briefly push trunk behind entities so the axe swing crosses it.
	_trunk.z_as_relative = false
	_trunk.z_index = ZLayers.WORLD_ENTITIES - 1

	if _trunk_tween != null:
		_trunk_tween.kill()
		_trunk_tween = null
	_trunk_tween = create_tween()
	_trunk_tween.tween_interval(0.18)
	_trunk_tween.tween_callback(Callable(self, "_restore_trunk_layer"))


func _restore_trunk_layer() -> void:
	if _trunk == null or not is_instance_valid(_trunk):
		return
	_trunk.z_as_relative = _trunk_z_as_relative
	_trunk.z_index = _trunk_z_index
