class_name PlacementManager
extends Node2D

## Handles "place item in front of player" preview + execution.
## Currently supports seed placement via `SeedItemData` script.

const SEED_ITEM_SCRIPT := preload("res://game/entities/items/models/seed_item_data.gd")
const SHOVEL_SOUND_PATH := preload("res://assets/sounds/tools/shovel.ogg")

@export var ghost_valid_color: Color = Color(0.3, 1.0, 0.3, 0.85)
@export var ghost_invalid_color: Color = Color(1.0, 0.3, 0.3, 0.85)
@export var tile_highlight_valid_color: Color = Color(0.3, 1.0, 0.3, 0.25)
@export var tile_highlight_invalid_color: Color = Color(1.0, 0.3, 0.3, 0.25)
@export_range(8, 128, 1) var tile_highlight_texture_size: int = 32

var player: Player = null
var _carried_item: ItemData = null
var _carried_slot_index: int = -1
var _preview_display_offset: Vector2 = Vector2.ZERO
var _preview_uses_atlas: bool = false

@onready var ghost_sprite: Sprite2D = $GhostSprite
var _tile_highlight: Sprite2D = null


func _ready() -> void:
	player = owner as Player
	if ghost_sprite != null:
		ghost_sprite.centered = true
		ghost_sprite.visible = false

	_tile_highlight = Sprite2D.new()
	_tile_highlight.name = "TileHighlight"
	_tile_highlight.centered = true
	_tile_highlight.z_index = 49  # just under ghost sprite
	_tile_highlight.visible = false
	_tile_highlight.texture = _make_faded_corner_texture(tile_highlight_texture_size)
	add_child(_tile_highlight)


func set_carried(item: ItemData, slot_index: int) -> void:
	_carried_item = item
	_carried_slot_index = slot_index
	_refresh_ghost_visuals()


func clear_carried() -> void:
	_carried_item = null
	_carried_slot_index = -1
	_refresh_ghost_visuals()


func is_active() -> bool:
	# Only show placement preview for placeable items.
	# TODO: Add other item types here.
	return _carried_item != null and _carried_item.get_script() == SEED_ITEM_SCRIPT


func _process(_delta: float) -> void:
	if ghost_sprite == null or _tile_highlight == null:
		return
	if not is_active() or player == null or player.raycell_component == null:
		ghost_sprite.visible = false
		_tile_highlight.visible = false
		return

	var cell := _get_placement_cell()
	if WorldGrid == null or WorldGrid.tile_map == null:
		ghost_sprite.visible = false
		_tile_highlight.visible = false
		return

	# TileMapManager.cell_to_global() uses TileMapLayer.map_to_local(),
	# which is already the cell center in Godot 4.
	var world_pos := WorldGrid.tile_map.cell_to_global(cell)
	ghost_sprite.visible = true
	var offset := _preview_display_offset if _preview_uses_atlas else Vector2.ZERO
	ghost_sprite.global_position = world_pos + offset

	var ok := _can_place_at(cell)
	ghost_sprite.modulate = ghost_valid_color if ok else ghost_invalid_color

	_tile_highlight.visible = true
	_tile_highlight.global_position = world_pos
	_tile_highlight.modulate = tile_highlight_valid_color if ok else tile_highlight_invalid_color
	_tile_highlight.scale = _compute_cell_scale(cell)


func try_place() -> bool:
	var cell := _get_placement_cell()
	if cell == Vector2i.ZERO or not _can_place_at(cell):
		return false

	if _carried_item != null and _carried_item.get_script() == SEED_ITEM_SCRIPT:
		var plant_v: Variant = _carried_item.get("plant_data")
		if not (plant_v is PlantData):
			return false
		var plant_data := plant_v as PlantData

		var ok := WorldGrid.plant_seed(cell, StringName(plant_data.resource_path))
		if not ok:
			return false

		# VFX & SFX
		if VFXManager:
			# Use tile break effect with soil colors
			var brown1 = Color(0.4, 0.25, 0.1)
			var brown2 = Color(0.35, 0.2, 0.1)
			VFXManager._spawn_effect(
				VFXManager.tile_break_config,
				WorldGrid.tile_map.cell_to_global(cell),
				10,
				[brown1, brown2]
			)

		if SFXManager:
			# Play a soft dig/place sound
			SFXManager.play_effect(SHOVEL_SOUND_PATH, global_position, Vector2(1.1, 1.3))

		# Consume 1 from the carried slot.
		player.inventory.remove_from_slot(_carried_slot_index, 1)

		# Refresh selection (slot may have become empty).
		if player.tool_manager != null and player.tool_manager.has_method("refresh_selection"):
			player.tool_manager.call("refresh_selection")
		return true

	return false


func _get_placement_cell() -> Vector2i:
	if not is_active() or player == null or player.inventory == null:
		return Vector2i.ZERO
	if player.raycell_component == null or WorldGrid == null:
		return Vector2i.ZERO

	var v: Variant = player.raycell_component.get_front_cell()
	if not (v is Vector2i):
		return Vector2i.ZERO
	return v as Vector2i


func _refresh_ghost_visuals() -> void:
	if ghost_sprite == null:
		return
	if _carried_item == null:
		_preview_uses_atlas = false
		_preview_display_offset = Vector2.ZERO
		ghost_sprite.visible = false
		if _tile_highlight != null:
			_tile_highlight.visible = false
		ghost_sprite.texture = null
		ghost_sprite.region_enabled = false
		ghost_sprite.centered = true
		return

	_preview_uses_atlas = false
	_preview_display_offset = Vector2.ZERO

	# Seeds preview as the actual plant sprite (stage 0, variant 0) so it matches placement.
	if _carried_item.get_script() == SEED_ITEM_SCRIPT:
		var plant_v: Variant = _carried_item.get("plant_data")
		if plant_v is PlantData:
			var pd := plant_v as PlantData
			if pd.source_atlas != null:
				_preview_uses_atlas = true
				_preview_display_offset = pd.display_offset
				ghost_sprite.texture = pd.source_atlas
				ghost_sprite.region_enabled = true
				ghost_sprite.region_rect = pd.get_region_rect(0, 0)
				ghost_sprite.centered = false
				ghost_sprite.visible = is_active()
				if _tile_highlight != null:
					_tile_highlight.visible = is_active()
				return

		# Fallback: show the item icon if the PlantData is missing/invalid.
		if _carried_item.icon is Texture2D:
			ghost_sprite.texture = _carried_item.icon
		else:
			ghost_sprite.texture = null
		ghost_sprite.region_enabled = false
		ghost_sprite.centered = true
	elif _carried_item.icon is Texture2D:
		ghost_sprite.texture = _carried_item.icon
		ghost_sprite.region_enabled = false
		ghost_sprite.centered = true
	else:
		ghost_sprite.texture = null
		ghost_sprite.region_enabled = false
		ghost_sprite.centered = true

	ghost_sprite.visible = is_active()
	if _tile_highlight != null:
		_tile_highlight.visible = is_active()


func _can_place_at(cell: Vector2i) -> bool:
	if WorldGrid == null or not WorldGrid.ensure_initialized():
		return false

	# Placement requires no obstacles and no existing plant.
	if WorldGrid.occupancy != null:
		if WorldGrid.has_method("has_any_obstacle_at") and WorldGrid.has_any_obstacle_at(cell):
			return false
		if WorldGrid.occupancy.get_entity_of_type(cell, Enums.EntityType.PLANT) != null:
			return false

	# Seeds require soil.
	var t := (
		WorldGrid.terrain_state.get_terrain_at(cell)
		if WorldGrid.terrain_state != null
		else GridCellData.TerrainType.NONE
	)
	return t == GridCellData.TerrainType.SOIL or t == GridCellData.TerrainType.SOIL_WET


func _compute_cell_scale(cell: Vector2i) -> Vector2:
	# Scale highlight texture to the tile size in world space.
	if WorldGrid == null or WorldGrid.tile_map == null:
		return Vector2.ONE * 16.0
	var p := WorldGrid.tile_map.cell_to_global(cell)
	var px := WorldGrid.tile_map.cell_to_global(cell + Vector2i.RIGHT)
	var py := WorldGrid.tile_map.cell_to_global(cell + Vector2i.DOWN)
	var right := px - p
	var down := py - p
	# Convert from pixel texture size to world units.
	var w := maxf(1.0, right.length())
	var h := maxf(1.0, down.length())
	var tex_w := float(tile_highlight_texture_size)
	var tex_h := float(tile_highlight_texture_size)
	return Vector2(w / tex_w, h / tex_h)


func _make_faded_corner_texture(size_px: int) -> Texture2D:
	# Makes a square texture that is mostly solid but fades at corners.
	# We keep the "core" visible while softly fading the corners.
	var s := maxi(8, size_px)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			# u/v in [-1, 1] across the texture
			var u := ((float(x) + 0.5) / float(s)) * 2.0 - 1.0
			var v := ((float(y) + 0.5) / float(s)) * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			# Fade starts near the edges, stronger in corners (since d is larger there).
			# Tuned so edges stay fairly visible but corners soften.
			var a := 1.0 - smoothstep(1.0, 1.35, d)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
