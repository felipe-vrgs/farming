extends GPUParticles2D

func _ready() -> void:
	# So this can be spawned as a child of Player without inheriting Player transforms.
	top_level = true
	one_shot = true
	emitting = true
	if has_signal("finished"):
		finished.connect(queue_free)
	else:
		get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)

