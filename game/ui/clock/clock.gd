extends Control

## If true, prefix the time with the day number.
@export var show_day: bool = true

const _WEEKDAYS := ["Mon.", "Tue.", "Wed.", "Thu.", "Fri.", "Sat.", "Sun."]

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _progress_container: Control = %DayProgress
@onready var _progress_back: ColorRect = %Back
@onready var _progress_fill: ColorRect = %Fill
@onready var _progress_marker: ColorRect = %Marker
@onready var _sun_icon: TextureRect = %SunIcon
@onready var _moon_icon: TextureRect = %MoonIcon

var _player: Node = null
var _last_money: int = -2147483648
var _last_day_progress: float = -1.0
var _last_hour_24: int = -1


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if TimeManager != null and not TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.connect(_on_time_changed)
	if (
		_progress_container != null
		and not _progress_container.resized.is_connected(_on_progress_container_resized)
	):
		_progress_container.resized.connect(_on_progress_container_resized)

	# First paint.
	_update_all()
	# Ensure the progress bar fill matches the computed size immediately.
	_on_progress_container_resized()


func _exit_tree() -> void:
	if TimeManager != null and TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.disconnect(_on_time_changed)
	if (
		_progress_container != null
		and _progress_container.resized.is_connected(_on_progress_container_resized)
	):
		_progress_container.resized.disconnect(_on_progress_container_resized)


func _process(_delta: float) -> void:
	# Best-effort: track player for money display, even across loads.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER)
	_update_money()


func _on_time_changed(_day_index: int, _minute_of_day: int, _day_progress: float) -> void:
	_update_all()


func _update_all() -> void:
	if TimeManager == null:
		if _day_label != null:
			_day_label.text = ""
		if _time_label != null:
			_time_label.text = "--:--"
		_set_day_progress(0.0)
		return

	_update_day()
	_update_time()
	_set_day_progress(float(TimeManager.get_day_progress()))
	_apply_day_night_style()
	_update_money()


func _update_day() -> void:
	if _day_label == null:
		return
	if not show_day:
		_day_label.visible = false
		return
	_day_label.visible = true

	var day_num := int(TimeManager.current_day) if TimeManager != null else 0
	var idx := int((day_num - 1) % _WEEKDAYS.size()) if day_num > 0 else 0
	var weekday = _WEEKDAYS[idx]
	_day_label.text = "%s %d" % [weekday, maxi(1, day_num)]


func _update_time() -> void:
	if _time_label == null:
		return
	if TimeManager == null:
		_time_label.text = "--:--"
		return

	var hh24 := int(TimeManager.get_hour()) % 24
	var mm := int(TimeManager.get_minute()) % 60
	var is_pm := hh24 >= 12
	var hh12 := hh24 % 12
	if hh12 == 0:
		hh12 = 12
	_time_label.text = "%d:%02d %s" % [hh12, mm, "pm" if is_pm else "am"]
	_last_hour_24 = hh24


func _apply_day_night_style() -> void:
	# Lightweight style shift so the clock feels "alive" like Stardew:
	# - warm daytime bar + brighter sun icon
	# - cool nighttime bar + brighter moon icon
	if TimeManager == null:
		return
	var hh24 := int(TimeManager.get_hour()) % 24
	var is_day := hh24 >= 6 and hh24 < 18

	# Icons
	if _sun_icon != null:
		_sun_icon.self_modulate = Color(1, 1, 1, 1.0) if is_day else Color(1, 1, 1, 0.35)
	if _moon_icon != null:
		_moon_icon.self_modulate = Color(1, 1, 1, 0.35) if is_day else Color(1, 1, 1, 1.0)

	# Bar colors
	if _progress_back != null:
		_progress_back.color = (
			Color(0.12, 0.08, 0.05, 0.75) if is_day else Color(0.06, 0.08, 0.14, 0.85)
		)
	if _progress_fill != null:
		_progress_fill.color = (
			Color(0.98, 0.83, 0.32, 0.90) if is_day else Color(0.45, 0.65, 1.00, 0.90)
		)
	if _progress_marker != null:
		_progress_marker.color = Color(1, 1, 1, 0.90) if is_day else Color(0.95, 0.98, 1.00, 0.95)


func _update_money() -> void:
	if _money_label == null:
		return
	var amt := 0
	if _player != null and is_instance_valid(_player) and "money" in _player:
		amt = int(_player.money)
	if amt == _last_money:
		return
	_last_money = amt
	_money_label.text = "%d" % amt


func _on_progress_container_resized() -> void:
	# Keep bar fill consistent if the HUD layout changes (resolution/UI scale).
	_set_day_progress(_last_day_progress)


func _set_day_progress(v: float) -> void:
	var p := clampf(float(v), 0.0, 1.0)
	_last_day_progress = p
	if _progress_container == null or _progress_fill == null:
		return

	# Ensure back always fills the container.
	if _progress_back != null:
		_progress_back.set_deferred("size", _progress_container.size)

	_progress_fill.position = Vector2.ZERO
	_progress_fill.set_deferred(
		"size", Vector2(_progress_container.size.x * p, _progress_container.size.y)
	)

	# Marker: shows the current time position (more "clock-like" than fill alone).
	if _progress_marker != null:
		var mw := maxf(2.0, _progress_marker.size.x)
		var x := (_progress_container.size.x * p) - (mw * 0.5)
		x = clampf(x, 0.0, maxf(0.0, _progress_container.size.x - mw))
		_progress_marker.position = Vector2(x, _progress_marker.position.y)
