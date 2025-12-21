class_name SoilInteractivityManager
extends Node

func interact_at_cell(cell: Vector2i) -> void:
	# Central place for future tool/actions (hoe, seed, water, harvest...).
	# For now: same behavior as before (till dirt -> spawn soil, then water).
	SoilGridState.try_farm_at_cell(cell)

