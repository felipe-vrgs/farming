class_name CellInteractionQuery
extends RefCounted

## Result of querying a cell for interaction targets.
## - entities: ordered list of targets to consider
## - has_obstacle: if true, terrain/soil should not be interactable "behind" this cell

var entities: Array[Node] = []
var has_obstacle: bool = false
