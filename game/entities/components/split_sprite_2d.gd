@tool
class_name SplitSprite2D
extends Node2D

## SplitSprite2D
## Authoring helper for tall-sprite partial occlusion.
##
## - Creates/maintains two Sprite2D children: BaseSprite2D + TopSprite2D.
## - Uses an atlas texture + region and splits it at `split_y_px` (from the top).
## - Base is Y-sorted normally under Entities.
## - Top is forced to render above entities (absolute z, ZLayers.ABOVE_ENTITIES).
##
## Pivot policy:
## - This node's origin is the *feet/base contact point* (bottom-center of the full region).
## - Sprites are placed with `centered=false` and positioned so the full art sits above the pivot.

@export var atlas: Texture2D:
	set(v):
		atlas = v
		_queue_rebuild()

@export var region: Rect2 = Rect2(0, 0, 16, 16):
	set(v):
		region = v
		_queue_rebuild()

## Split line from the TOP of the region (in pixels).
## - Top slice: [0..split_y_px)
## - Base slice: [split_y_px..height)
@export_range(1, 512, 1) var split_y_px: int = 16:
	set(v):
		split_y_px = v
		_queue_rebuild()

@export var base_node_name: StringName = &"BaseSprite2D":
	set(v):
		base_node_name = v
		_queue_rebuild()

@export var top_node_name: StringName = &"TopSprite2D":
	set(v):
		top_node_name = v
		_queue_rebuild()

@export var top_z_index: int = ZLayers.ABOVE_ENTITIES:
	set(v):
		top_z_index = v
		_queue_rebuild()

var _base_sprite: Sprite2D
var _top_sprite: Sprite2D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	_ensure_children()
	if atlas == null:
		return

	var w := int(maxf(1.0, region.size.x))
	var h := int(maxf(1.0, region.size.y))
	var split := clampi(split_y_px, 1, h - 1)

	# Create atlas textures for each slice.
	var top_at := AtlasTexture.new()
	top_at.atlas = atlas
	top_at.region = Rect2(region.position.x, region.position.y, region.size.x, float(split))

	var base_at := AtlasTexture.new()
	base_at.atlas = atlas
	base_at.region = Rect2(
		region.position.x,
		region.position.y + float(split),
		region.size.x,
		region.size.y - float(split)
	)

	# Place sprites so this node origin is bottom-center of the full region.
	# Using centered=false: sprite position is its top-left corner.
	var x0 := -float(w) * 0.5
	_base_sprite.centered = false
	_top_sprite.centered = false

	_base_sprite.texture = base_at
	_top_sprite.texture = top_at

	_base_sprite.position = Vector2(x0, -float(h - split))
	_top_sprite.position = Vector2(x0, -float(h))

	# Ensure Top always renders above entities.
	_top_sprite.z_as_relative = false
	_top_sprite.z_index = int(top_z_index)

	# Base stays relative (inherits the Entities band); keep it neutral.
	_base_sprite.z_as_relative = true
	_base_sprite.z_index = 0


func _queue_rebuild() -> void:
	# Rebuild only when we can safely touch the scene tree.
	if not is_inside_tree() and not Engine.is_editor_hint():
		return
	call_deferred("_rebuild")


func _ensure_children() -> void:
	var b := get_node_or_null(NodePath(String(base_node_name)))
	if b is Sprite2D:
		_base_sprite = b as Sprite2D
	else:
		_base_sprite = Sprite2D.new()
		_base_sprite.name = String(base_node_name)
		add_child(_base_sprite)
		_maybe_set_owner(_base_sprite)

	var t := get_node_or_null(NodePath(String(top_node_name)))
	if t is Sprite2D:
		_top_sprite = t as Sprite2D
	else:
		_top_sprite = Sprite2D.new()
		_top_sprite.name = String(top_node_name)
		add_child(_top_sprite)
		_maybe_set_owner(_top_sprite)


func _maybe_set_owner(n: Node) -> void:
	# Make tool-created children persist in the .tscn and show up in the editor tree.
	if not Engine.is_editor_hint():
		return
	if n == null:
		return
	var o := get_owner()
	if o != null:
		n.owner = o


func _enter_tree() -> void:
	# In-editor: create children immediately so NodePath pickers can see them.
	if Engine.is_editor_hint():
		_ensure_children()
		_queue_rebuild()
