class_name ZLayers
extends RefCounted

## ZLayers
## Centralized z-index bands for consistent 2D draw ordering.
##
## Policy:
## - TileMap layers use fixed z bands (ground/overlays/shadows/walls/tops).
## - Dynamic entities live under a Y-sorted container at WORLD_ENTITIES.
## - Use only these constants in code (avoid magic numbers).
##
## Notes:
## - These values intentionally match the repo's current scene defaults to minimize churn.

const GROUND := 1
const GROUND_OVERLAY := 2
const SOIL_WET_OVERLAY := 3

const SHADOWS := 6

const WALLS := 10
const WALL_OVERLAY := 11

## Parent z-index for the main Y-sorted entities root (player/NPC/items/plants).
const WORLD_ENTITIES := 15

## Things that should always draw above entities (e.g., wall tops / canopies).
const ABOVE_ENTITIES := 20

## Extremely foreground things (e.g., travel zones markers, item "pop" animation override).
const FOREGROUND := 99

## Debug draw helpers (gizmos/lines/markers).
const DEBUG := 1000


static func apply_world_entity(node: CanvasItem) -> void:
	if node == null:
		return
	node.z_index = 0
