class_name ChangeLayerOnHitComponent
extends Node

## Temporarily changes a sprite's z-layer when hit by a tool.
## This helps the tool swing visibly cross over the sprite (e.g. axe through tree trunk).
##
## Auto-connects to DamageOnInteract.tool_hit signal if found in siblings.
## No parent script required.

## Sprites to temporarily push behind the player/tool layer.
@export var target_sprites: Array[CanvasItem] = []

## Only react to hits from this tool type (or ANY if set to NONE).
@export var tool_filter: Enums.ToolActionKind = Enums.ToolActionKind.AXE

## How far to push the sprite behind. Negative = further behind.
@export var layer_offset: int = -1

## How long to keep the sprite behind before restoring.
@export var duration: float = 0.18

## Auto-connect to DamageOnInteract signal if found (no parent script needed).
@export var auto_connect: bool = true

var _original_z_data: Array[Dictionary] = []
var _restore_tween: Tween = null
var _connected: bool = false


func _ready() -> void:
	# Cache original z values.
	_original_z_data.clear()
	for sprite in target_sprites:
		if sprite != null:
			_original_z_data.append(
				{"sprite": sprite, "z_as_relative": sprite.z_as_relative, "z_index": sprite.z_index}
			)

	if auto_connect:
		# Defer so dynamically created components are ready.
		call_deferred("_auto_connect_to_damage_signal")


func _auto_connect_to_damage_signal() -> void:
	if _connected:
		return

	var entity := get_parent()
	if entity == null:
		return

	# Search for DamageOnInteract in siblings and children.
	var candidates: Array[Node] = []

	# Check direct siblings
	for sibling in entity.get_children():
		if sibling is DamageOnInteract:
			candidates.append(sibling)
		# Check grandchildren (e.g. HealthComponent/DamageOnInteract)
		for child in sibling.get_children():
			if child is DamageOnInteract:
				candidates.append(child)

	# Connect to all found DamageOnInteract components.
	for doi in candidates:
		if doi.has_signal("tool_hit") and not doi.is_connected("tool_hit", _on_tool_hit):
			doi.connect("tool_hit", _on_tool_hit)
			_connected = true


func _on_tool_hit(ctx: InteractionContext) -> void:
	if ctx == null:
		return

	# Filter by tool type (NONE means accept all).
	if tool_filter != Enums.ToolActionKind.NONE:
		if not ctx.is_tool(tool_filter):
			return

	_push_layer()


## Call this manually from parent's `on_tool_hit()` if not auto-connecting.
func on_tool_hit(ctx: InteractionContext) -> void:
	_on_tool_hit(ctx)


func _push_layer() -> void:
	if target_sprites.is_empty():
		return

	# Push sprites behind the world entities layer.
	for sprite in target_sprites:
		if sprite == null or not is_instance_valid(sprite):
			continue
		sprite.z_as_relative = false
		sprite.z_index = ZLayers.WORLD_ENTITIES + layer_offset

	# Schedule restore.
	if _restore_tween != null:
		_restore_tween.kill()
		_restore_tween = null

	_restore_tween = create_tween()
	_restore_tween.tween_interval(duration)
	_restore_tween.tween_callback(_restore_layer)


func _restore_layer() -> void:
	for data in _original_z_data:
		var sprite := data.get("sprite") as CanvasItem
		if sprite == null or not is_instance_valid(sprite):
			continue
		sprite.z_as_relative = data.get("z_as_relative", true)
		sprite.z_index = data.get("z_index", 0)
