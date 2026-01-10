class_name EnergyBar
extends Control

@onready var _fill: Control = $PanelContainer/MarginContainer/Gauge/Fill
@onready var _gauge: Control = $PanelContainer/MarginContainer/Gauge
@onready var _debug_label: Label = $PanelContainer/MarginContainer/DebugLabel

var _energy: EnergyComponent = null
var _last_current: float = 0.0
var _last_max: float = 0.0


func _ready() -> void:
	# Wait for layout to compute sizes, otherwise the gauge can start at 0 height.
	if _gauge != null:
		var cb := Callable(self, "_on_gauge_resized")
		if not _gauge.resized.is_connected(cb):
			_gauge.resized.connect(cb)

	_update_visual(0.0, 0.0)
	_update_debug_label_visibility()
	call_deferred("_refresh_visual")


func _process(_delta: float) -> void:
	# F4 is an input toggle in debug tools; poll for visibility changes.
	_update_debug_label_visibility()


func rebind(player: Player = null) -> void:
	if player == null or not is_instance_valid(player) or not ("energy_component" in player):
		_rebind_energy(null)
		return
	_rebind_energy(player.energy_component)


func _rebind_energy(ec: EnergyComponent) -> void:
	# Disconnect old.
	if _energy != null and is_instance_valid(_energy):
		var old_cb := Callable(self, "_on_energy_changed")
		if _energy.is_connected("energy_changed", old_cb):
			_energy.disconnect("energy_changed", old_cb)

	_energy = ec

	# Connect new.
	if _energy != null and is_instance_valid(_energy):
		var cb := Callable(self, "_on_energy_changed")
		if not _energy.is_connected("energy_changed", cb):
			_energy.connect("energy_changed", cb)
		_update_visual(_energy.current_energy, _energy.max_energy)
		visible = true
	else:
		_update_visual(0.0, 0.0)
		visible = false
	_update_debug_label_visibility()


func _on_energy_changed(current: float, max_v: float) -> void:
	_update_visual(current, max_v)


func _update_visual(current: float, max_v: float) -> void:
	_last_current = current
	_last_max = max_v

	if _fill != null and _gauge != null:
		var ratio := 0.0
		if max_v > 0.0:
			ratio = clampf(current / max_v, 0.0, 1.0)
		var h := maxf(0.0, _gauge.size.y)
		var fill_h := roundf(h * ratio)
		# Keep a tiny sliver visible when non-zero (Stardew-ish readability).
		if ratio > 0.0:
			fill_h = maxf(fill_h, 2.0)
		_fill.size = Vector2(_gauge.size.x, fill_h)
		_fill.position = Vector2(0.0, h - fill_h)

	if _debug_label != null:
		if max_v <= 0.0:
			_debug_label.text = ""
		else:
			_debug_label.text = "%d/%d" % [int(round(current)), int(round(max_v))]


func _on_gauge_resized() -> void:
	_refresh_visual()


func _refresh_visual() -> void:
	# Recompute fill using the latest values after layout/resize.
	_update_visual(_last_current, _last_max)


func _update_debug_label_visibility() -> void:
	if _debug_label == null:
		return
	if not OS.is_debug_build():
		_debug_label.visible = false
		return
	if _energy == null or not is_instance_valid(_energy):
		_debug_label.visible = false
		return

	# Only show numbers when the debug travel-zones/markers overlay is enabled (F4).
	var show := false
	if is_instance_valid(Debug) and "grid" in Debug and Debug.grid != null:
		var grid = Debug.grid
		if is_instance_valid(grid) and grid.has_method("is_markers_enabled"):
			show = bool(grid.call("is_markers_enabled"))
	_debug_label.visible = show
