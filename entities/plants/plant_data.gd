class_name PlantData
extends Resource

## The name of the plant displayed to the player
@export var plant_name: String = "Unnamed Plant"

## How many days it takes to reach maturity
@export var days_to_grow: int = 3

## The item name produced when harvested
@export var harvest_item_name: String

## Sprites for each growth stage.
## Index 0 is the seed/sprout, last index is the harvestable stage.
@export var sprites: Array[Texture2D]

