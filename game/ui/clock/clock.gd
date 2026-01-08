extends Control

## If true, prefix the time with the day number.
@export var show_day: bool = true

@onready var _time_label: Label = $TimeLabel


func _ready() -> void:
	_update_text()
	if TimeManager != null and not TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.connect(_on_time_changed)


func _exit_tree() -> void:
	if TimeManager != null and TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.disconnect(_on_time_changed)


func _on_time_changed(_day_index: int, _minute_of_day: int, _day_progress: float) -> void:
	_update_text()


func _update_text() -> void:
	if TimeManager == null:
		_time_label.text = "--:--"
		return

	var hh := int(TimeManager.get_hour()) % 24
	var mm := int(TimeManager.get_minute()) % 60

	if show_day:
		_time_label.text = "D%d\n%02d:%02d" % [int(TimeManager.current_day), hh, mm]
	else:
		_time_label.text = "%02d:%02d" % [hh, mm]
