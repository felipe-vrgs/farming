class_name QuestPopupQueue
extends RefCounted

## Small queue/pump helper for quest popups.
## - Handles priority (completed before started)
## - Handles modal deferral (reward presentation, HUD not visible yet)
## - Handles one-time initial delay (game start UI churn)
## - Pumps sequentially so popups don't overwrite each other


class Event:
	var kind: String = ""
	var quest_id: StringName = &""
	var step_index: int = 0
	var title: String = ""
	var heading: String = ""
	var entries: Array = []
	var duration: float = 0.0


var _owner: Node
var _should_defer: Callable
var _on_event: Callable

var _queue: Array[Event] = []  # standardized event payloads
var _pumping: bool = false
var _initial_delay_sec: float = 0.0

const _DEFAULT_DISPLAY_SEC := 4.35
const _POST_EVENT_BUFFER_SEC := 0.35


func _init(owner: Node, should_defer: Callable, on_event: Callable) -> void:
	_owner = owner
	_should_defer = should_defer
	_on_event = on_event


func ensure_initial_delay(sec: float) -> void:
	_initial_delay_sec = maxf(_initial_delay_sec, maxf(0.0, sec))


func enqueue(ev: Event) -> void:
	if ev == null:
		return
	# De-dupe: if multiple queued notifications reference the same quest,
	# only keep the most recent (prevents stale popups).
	var qid: StringName = ev.quest_id
	if not String(qid).is_empty():
		for i in range(_queue.size() - 1, -1, -1):
			var e := _queue[i]
			if e is Event and e.quest_id == qid:
				_queue.remove_at(i)
	var kind := ev.kind
	if kind == "completed":
		# Ensure quest completion is shown before any queued quest-started popups
		# (e.g. when completing a quest auto-starts the next unlocked quest).
		_queue.insert(0, ev)
	else:
		_queue.append(ev)
	_pump()


func pump() -> void:
	# Public nudge: call this when deferral conditions may have changed.
	_pump()


func clear() -> void:
	# Drop queued notifications (used when entering dialogue/cutscenes).
	_queue.clear()
	_initial_delay_sec = 0.0


func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	# Run async without blocking signal handler stack.
	call_deferred("_pump_async")


func _pump_async() -> void:
	await _pump_loop()


func _pump_loop() -> void:
	while not _queue.is_empty():
		if _should_defer.is_valid() and bool(_should_defer.call()):
			break

		# One-time delay to avoid the popup getting hidden by initial game start UI churn.
		if _initial_delay_sec > 0.0 and _owner != null and is_instance_valid(_owner):
			var d := _initial_delay_sec
			_initial_delay_sec = 0.0
			await _owner.get_tree().create_timer(d, true).timeout

		var ev = _queue.pop_front()
		if ev == null:
			continue
		if _on_event.is_valid():
			_on_event.call(ev)

		if _owner != null and is_instance_valid(_owner):
			var duration := float(ev.duration)
			await (
				_owner
				. get_tree()
				. create_timer(maxf(0.1, duration + _POST_EVENT_BUFFER_SEC), true)
				. timeout
			)

	_pumping = false
