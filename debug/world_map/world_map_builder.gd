@tool
extends Node2D

## WorldMapBuilder - Generates a merged view of all levels for editing routes.
##
## Usage:
## 1. Open this scene.
## 2. Assign a WorldEditorLayout resource.
## 3. Click "Rebuild World" (exported bool/button).
## 4. Draw routes across levels!

@export var layout: WorldEditorLayout
var _rebuild_requested: bool = false
@export var rebuild: bool = false:
	get:
		return _rebuild_requested
	set(value):
		# NOTE: Never assign to `rebuild` inside this setter (would recurse and can lock the editor).
		_rebuild_requested = bool(value)
		if _rebuild_requested:
			_rebuild_world()
			_rebuild_requested = false

var _clear_requested: bool = false
@export var clear: bool = false:
	get:
		return _clear_requested
	set(value):
		# NOTE: Never assign to `clear` inside this setter (would recurse and can lock the editor).
		_clear_requested = bool(value)
		if _clear_requested:
			_clear_world()
			_clear_requested = false

# Container for the level instances
var _levels_container: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		# Don't auto-build on open, might be heavy.
		pass


func _clear_world() -> void:
	# Remove all children that are not the script owner or internal tools
	for child in get_children():
		if child.owner == null:  # Temporary nodes
			child.queue_free()
		elif child.name == "Levels":
			child.queue_free()
			child.name = "Levels_Deleted"  # Prevent name collision before free


func _rebuild_world() -> void:
	if layout == null:
		push_error("WorldMapBuilder: No layout assigned!")
		return

	_clear_world()

	_levels_container = Node2D.new()
	_levels_container.name = "Levels"
	add_child(_levels_container)
	# Important: Don't set owner for these, so they aren't saved into the scene file!
	# We want this scene to be a "viewer", not a monolith file.

	print("WorldMapBuilder: Building world map...")

	for level_id_var in layout.level_scenes.keys():
		var level_id = int(level_id_var)
		var path = layout.get_level_scene_path(level_id)
		var offset = layout.get_level_offset(level_id)

		if path == "" or not FileAccess.file_exists(path):
			push_warning("WorldMapBuilder: Invalid path for level %s: %s" % [level_id, path])
			continue

		var scene = load(path)
		if scene:
			var instance = scene.instantiate()
			instance.name = "Level_%s" % level_id
			instance.position = offset
			_levels_container.add_child(instance)

			# Add a debug label
			var label = Label.new()
			label.text = "LEVEL %s" % level_id
			label.position = Vector2(0, -50)
			label.scale = Vector2(2, 2)
			label.modulate = Color.YELLOW
			instance.add_child(label)

	print("WorldMapBuilder: Done.")
