class_name EnergyComponent
extends Node

## Tracks per-day energy (stamina-like resource).
## - Refills at 06:00 via EventBus.day_started.
## - Forced sleeps (2AM or exhaustion collapse) can apply a wake-up penalty.

signal energy_changed(current: float, max: float)
signal depleted

@export var max_energy: float = 100.0
@export var current_energy: float = 100.0

@export_group("Wake-up Penalty")
## When true at 06:00 refill, wake up with (max_energy * forced_wakeup_multiplier).
@export var forced_wakeup_multiplier: float = 0.8

@export_group("Movement Slow Tiers")
## >= tier_full_pct => full speed
@export_range(0.0, 1.0, 0.01) var tier_full_pct: float = 0.20
@export_range(0.0, 1.0, 0.01) var tier_mid_pct: float = 0.10
@export_range(0.1, 1.0, 0.01) var speed_full: float = 1.0
@export_range(0.1, 1.0, 0.01) var speed_mid: float = 0.85
@export_range(0.1, 1.0, 0.01) var speed_low: float = 0.70

var _forced_wakeup_pending: bool = false
var _depleted_emitted: bool = false


func _enter_tree() -> void:
	# Keep current clamped when loading instanced scenes.
	_sync_clamp(false)


func _ready() -> void:
	_sync_clamp(true)
	if Engine.is_editor_hint():
		return
	if EventBus != null and not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func get_energy_ratio() -> float:
	if max_energy <= 0.0:
		return 0.0
	return clampf(current_energy / max_energy, 0.0, 1.0)


func get_move_speed_multiplier() -> float:
	var r := get_energy_ratio()
	if r >= tier_full_pct:
		return speed_full
	if r >= tier_mid_pct:
		return speed_mid
	return speed_low


func set_forced_wakeup_pending() -> void:
	_forced_wakeup_pending = true


func is_forced_wakeup_pending() -> bool:
	return _forced_wakeup_pending


func clear_forced_wakeup_pending() -> void:
	_forced_wakeup_pending = false


func refill_for_new_day(is_forced: bool) -> void:
	var mult := 1.0
	if is_forced:
		mult = clampf(forced_wakeup_multiplier, 0.0, 1.0)
	current_energy = clampf(max_energy * mult, 0.0, max_energy)
	_depleted_emitted = false
	energy_changed.emit(current_energy, max_energy)


func spend_attempt(amount: float) -> void:
	_spend(amount)


func spend_success(amount: float) -> void:
	_spend(amount)


func set_energy(current: float, max_v: float = -1.0, emit_signal: bool = true) -> void:
	if max_v >= 0.0:
		max_energy = max_v
	current_energy = current
	_sync_clamp(emit_signal)


func _on_day_started(_day_index: int) -> void:
	var forced := _forced_wakeup_pending
	_forced_wakeup_pending = false
	refill_for_new_day(forced)


func _spend(amount: float) -> void:
	if amount <= 0.0:
		return
	if max_energy <= 0.0:
		return

	var prev := current_energy
	current_energy = clampf(current_energy - amount, 0.0, max_energy)
	if current_energy == prev:
		return

	energy_changed.emit(current_energy, max_energy)
	if current_energy <= 0.0 and not _depleted_emitted:
		_depleted_emitted = true
		depleted.emit()


func _sync_clamp(emit_signal: bool) -> void:
	max_energy = maxf(0.0, max_energy)
	current_energy = clampf(current_energy, 0.0, max_energy)
	if emit_signal:
		energy_changed.emit(current_energy, max_energy)
