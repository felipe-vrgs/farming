@tool
extends Control

var editor_interface: EditorInterface

@onready var tree: Tree = $VBoxContainer/Tree
@onready var refresh_btn: Button = $VBoxContainer/RefreshButton

func set_editor_interface(ei: EditorInterface) -> void:
	editor_interface = ei

func _ready() -> void:
	if not tree:
		return
	_refresh()

func _on_refresh_button_pressed() -> void:
	_refresh()

func _refresh() -> void:
	tree.clear()
	var root = tree.create_item()
	root.set_text(0, "Root")

	# List Sessions
	var sessions_root = tree.create_item(root)
	sessions_root.set_text(0, "Sessions (user://sessions)")
	sessions_root.set_selectable(0, false)
	_add_dir_contents("user://sessions", sessions_root)

	# List Saves
	var saves_root = tree.create_item(root)
	saves_root.set_text(0, "Saves (user://saves)")
	saves_root.set_selectable(0, false)
	_add_dir_contents("user://saves", saves_root)

func _add_dir_contents(path: String, parent: TreeItem) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path + "/" + file_name
				var item = tree.create_item(parent)
				item.set_text(0, file_name)
				item.set_metadata(0, full_path)

				if dir.current_is_dir():
					item.set_collapsed(true)
					_add_dir_contents(full_path, item)
				else:
					# Is file
					pass
			file_name = dir.get_next()
	else:
		# Directory might not exist yet
		pass

func _on_tree_item_activated() -> void:
	var item = tree.get_selected()
	if not item: return

	var path = item.get_metadata(0)
	if path and FileAccess.file_exists(path):
		# Only try to open resources
		if path.ends_with(".tres") or path.ends_with(".res"):
			print("Opening save file: ", path)
			var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res and editor_interface:
				editor_interface.edit_resource(res)
		else:
			print("Selected file is not a resource: ", path)
