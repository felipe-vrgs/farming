@tool
class_name WorldEditorLayout
extends Resource

## WorldEditorLayout - Configures where levels are placed in the merged World Map editor.
##
## This allows us to visualize the entire game world in one scene (for routing)
## without physically merging the level scenes.

## Dictionary mapping level_id (int/enum) -> Vector2 offset
@export var level_offsets: Dictionary = {
	Enums.Levels.ISLAND: Vector2.ZERO,
	Enums.Levels.FRIEREN_HOUSE: Vector2(2000, 0),
	Enums.Levels.PLAYER_HOUSE: Vector2(2000, 1000),
}

## Dictionary mapping level_id (int/enum) -> Scene Path (String)
@export var level_scenes: Dictionary = {
	Enums.Levels.ISLAND: "res://game/levels/island.tscn",
	Enums.Levels.FRIEREN_HOUSE: "res://game/levels/frieren_house.tscn",
	Enums.Levels.PLAYER_HOUSE: "res://game/levels/player_house.tscn",
}


func get_level_offset(level_id: int) -> Vector2:
	return level_offsets.get(level_id, Vector2.ZERO)


func get_level_scene_path(level_id: int) -> String:
	return level_scenes.get(level_id, "")
