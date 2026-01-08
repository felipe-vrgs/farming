class_name QuestPopupQueue
extends RefCounted

## Small queue/pump helper for quest popups.
## - Handles priority (completed before started)
## - Handles modal deferral (reward presentation, HUD not visible yet)
## - Handles one-time initial delay (game start UI churn)
## - Pumps sequentially so popups don't overwrite each other

var _owner: Node
var _should_defer: Callable
var _on_started: Callable
var _on_step: Callable
var _on_completed: Callable

var _queue: Array[Dictionary] = []  # {type:String, quest_id:StringName, step_index:int}
var _pumping: bool = false
var _initial_delay_sec: float = 0.0

const _DEFAULT_DISPLAY_SEC := 4.35


func _init(
	owner: Node,
	should_defer: Callable,
	on_started: Callable,
	on_step: Callable,
	on_completed: Callable
) -> void:
	_owner = owner
	_should_defer = should_defer
	_on_started = on_started
	_on_step = on_step
	_on_completed = on_completed


func ensure_initial_delay(sec: float) -> void:
	_initial_delay_sec = maxf(_initial_delay_sec, maxf(0.0, sec))


func enqueue(ev: Dictionary) -> void:
	if ev == null:
		return
	var typ := String(ev.get("type", ""))
	if typ == "completed":
		# Ensure quest completion is shown before any queued quest-started popups
		# (e.g. when completing a quest auto-starts the next unlocked quest).
		var qid: StringName = ev.get("quest_id", &"") as StringName
		if not String(qid).is_empty():
			# Also remove any queued step popups for this quest (avoid clashes).
			for i in range(_queue.size() - 1, -1, -1):
				var e := _queue[i]
				if e is Dictionary and String(e.get("type", "")) == "step":
					if (e.get("quest_id", &"") as StringName) == qid:
						_queue.remove_at(i)
		_queue.insert(0, ev)
	else:
		_queue.append(ev)
	_pump()


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
		var typ = String(ev.get("type", ""))
		if typ == "started":
			if _on_started.is_valid():
				_on_started.call(ev.get("quest_id", &"") as StringName)
		elif typ == "step":
			if _on_step.is_valid():
				_on_step.call(ev.get("quest_id", &"") as StringName, int(ev.get("step_index", -1)))
		elif typ == "completed":
			if _on_completed.is_valid():
				_on_completed.call(ev.get("quest_id", &"") as StringName)

		if _owner != null and is_instance_valid(_owner):
			await _owner.get_tree().create_timer(_DEFAULT_DISPLAY_SEC, true).timeout

	_pumping = false
