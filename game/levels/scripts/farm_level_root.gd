class_name FarmLevelRoot
extends LevelRoot

@export var soil_overlay_layer_path: NodePath = NodePath("GroundMaps/SoilOverlay")
@export var wet_overlay_layer_path: NodePath = NodePath("GroundMaps/SoilWetOverlay")


func get_soil_overlay_layer() -> TileMapLayer:
	return get_node_or_null(soil_overlay_layer_path) as TileMapLayer


func get_wet_overlay_layer() -> TileMapLayer:
	return get_node_or_null(wet_overlay_layer_path) as TileMapLayer
