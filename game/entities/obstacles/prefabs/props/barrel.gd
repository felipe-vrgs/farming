@tool
extends Obstacle

## Per-instance barrel variant selector.
## Uses a shared BarrelCatalog containing presets.

var _catalog: BarrelCatalog
@export var catalog: BarrelCatalog:
	get:
		return _catalog
	set(v):
		if _catalog == v:
			_apply_from_catalog()
			return
		_disconnect_catalog()
		_catalog = v
		_connect_catalog()
		_apply_from_catalog()

var _barrel_type: BarrelCatalog.BarrelType = BarrelCatalog.BarrelType.BARREL_1
@export var barrel_type: BarrelCatalog.BarrelType:
	get:
		return _barrel_type
	set(v):
		if _barrel_type == v:
			return
		_barrel_type = v
		_apply_from_catalog()


func _enter_tree() -> void:
	super._enter_tree()
	_connect_catalog()


func _exit_tree() -> void:
	_disconnect_catalog()
	super._exit_tree()


func _ready() -> void:
	# Ensure runtime applies the selected preset even if the catalog setter
	# didn't fire (e.g. load order / scene instancing).
	super._ready()
	_apply_from_catalog()


func _connect_catalog() -> void:
	if _catalog == null:
		return
	if not _catalog.changed.is_connected(_on_catalog_changed):
		_catalog.changed.connect(_on_catalog_changed)


func _disconnect_catalog() -> void:
	if _catalog == null:
		return
	if _catalog.changed.is_connected(_on_catalog_changed):
		_catalog.changed.disconnect(_on_catalog_changed)


func _on_catalog_changed() -> void:
	_apply_from_catalog()


func _apply_from_catalog() -> void:
	if _catalog == null:
		return
	var p := _catalog.get_preset(_barrel_type)
	if p == null:
		return
	# Godot's static analyzer sometimes can't see methods on instanced script bases.
	# Use call() to keep tooling happy.
	call("apply_preset", p)
