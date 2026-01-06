extends GameState


func enter(_prev: StringName = &"") -> void:
	# No-op. Boot is a transient state; GameFlow will move to MENU in normal runs.
	pass
