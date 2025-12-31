class_name NpcScheduleResolver
extends Node

## ScheduleResolver component (v1):
## - Lives under an NPC tree (recommended under `Components/`).
## - Owns schedule evaluation + applying results (state switching + travel).

const _MINUTES_PER_DAY := 24 * 60

class Resolved:
	var step: NpcScheduleStep = null
	var step_index: int = -1
	var minute_of_day: int = 0
	var progress: float = 0.0

var _npc: NPC = null
var _agent_component: AgentComponent = null
var _is_bound: bool = false

var _last_day_index: int = -1
var _last_step_index: int = -1

func _ready() -> void:
	_bind_to_npc()
	_connect_clock()
	_apply_now()
	set_process(true)

func _process(_delta: float) -> void:
	# If TimeManager wasn't ready at _ready(), try to connect later.
	if TimeManager != null and not TimeManager.time_changed.is_connected(_on_time_changed):
		_connect_clock()
		_apply_now()
	# If we tried to apply before the NPC state machine was initialized, retry once it is.
	if _npc != null and _last_day_index < 0 and TimeManager != null and _is_state_machine_ready():
		_apply_now()

func _exit_tree() -> void:
	if TimeManager != null and TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.disconnect(_on_time_changed)

func _bind_to_npc() -> void:
	if _is_bound:
		return
	_npc = _find_npc()
	if _npc == null:
		return
	_agent_component = ComponentFinder.find_component_in_group(
		_npc,
		Groups.AGENT_COMPONENTS
	) as AgentComponent
	_is_bound = true

func _find_npc() -> NPC:
	var p := get_parent()
	if p == null:
		return null
	if p.name == "Components" and p.get_parent() is NPC:
		return p.get_parent() as NPC
	if p is NPC:
		return p as NPC
	return null

func _connect_clock() -> void:
	if TimeManager == null:
		return
	if TimeManager.time_changed.is_connected(_on_time_changed):
		return
	TimeManager.time_changed.connect(_on_time_changed)

func _on_time_changed(day_index: int, minute_of_day: int, _day_progress: float) -> void:
	_apply(day_index, minute_of_day)

func _apply_now() -> void:
	if _npc == null:
		_bind_to_npc()
	if _npc == null:
		return
	if TimeManager == null:
		return
	_apply(int(TimeManager.current_day), int(TimeManager.get_minute_of_day()))

func _apply(day_index: int, minute_of_day: int) -> void:
	if _npc == null:
		return

	var sm_ready := _is_state_machine_ready()
	var schedule := _get_schedule()
	if schedule == null:
		# Only attempt state changes after the state machine is initialized.
		if sm_ready:
			_apply_hold()
		return

	var resolved := resolve(schedule, minute_of_day)
	var same_step := resolved.step_index == _last_step_index and day_index == _last_day_index

	if resolved.step == null:
		if sm_ready:
			_apply_hold()
			_last_day_index = day_index
			_last_step_index = resolved.step_index
		return

	# If we're already on this step, we usually don't need to do anything.
	# But schedule application can happen before the state machine is initialized
	# (NPC init is deferred), so we also re-apply if we're not actually in the
	# intended state yet.
	if same_step:
		match resolved.step.kind:
			NpcScheduleStep.Kind.ROUTE:
				if sm_ready:
					var wrong_state := not _is_in_state(NPCStateNames.ROUTE_IN_PROGRESS)
					if _npc.route_override_id == RouteIds.Id.NONE or wrong_state:
						_apply_route(resolved.step)
			NpcScheduleStep.Kind.TRAVEL:
				# Travel is idempotent-ish due to guards in _apply_travel(), but don't spam it.
				pass
			_:
				if sm_ready and not _is_in_state(NPCStateNames.IDLE):
					_apply_hold()
		return

	match resolved.step.kind:
		NpcScheduleStep.Kind.ROUTE:
			# Defer route application until the state machine has been initialized.
			if sm_ready:
				_apply_route(resolved.step)
				_last_day_index = day_index
				_last_step_index = resolved.step_index
		NpcScheduleStep.Kind.TRAVEL:
			if _apply_travel(resolved.step):
				_last_day_index = day_index
				_last_step_index = resolved.step_index
		_:
			if sm_ready:
				_apply_hold()
				_last_day_index = day_index
				_last_step_index = resolved.step_index

func _is_state_machine_ready() -> bool:
	# `StateMachine.change_state()` relies on its internal cache populated by `init()`.
	return (
		_npc != null
		and _npc.state_machine != null
		and _npc.state_machine.get_state(NPCStateNames.IDLE) != null
	)

func _is_in_state(state_name: StringName) -> bool:
	if _npc == null or _npc.state_machine == null or _npc.state_machine.current_state == null:
		return false
	return StringName(String(_npc.state_machine.current_state.name).to_snake_case()) == state_name

func _get_schedule() -> NpcSchedule:
	var cfg := _npc.npc_config
	if cfg == null:
		return null
	return cfg.schedule

func _apply_hold() -> void:
	_npc.route_override_id = RouteIds.Id.NONE
	_npc.route_looping = true
	_npc.change_state(NPCStateNames.IDLE)

func _apply_route(step: NpcScheduleStep) -> void:
	var active_level_id: Enums.Levels = (
		GameManager.get_active_level_id()
		if GameManager != null
		else Enums.Levels.NONE
	)
	if step.level_id != Enums.Levels.NONE and step.level_id != active_level_id:
		_apply_hold()
		return

	_npc.route_override_id = step.route_id
	_npc.route_looping = bool(step.loop_route)
	if _npc.route_override_id == RouteIds.Id.NONE:
		_apply_hold()
		return
	_npc.change_state(NPCStateNames.ROUTE_IN_PROGRESS)

func _apply_travel(step: NpcScheduleStep) -> bool:
	_npc.route_override_id = RouteIds.Id.NONE
	_npc.route_looping = true
	if AgentRegistry == null or GameManager == null:
		return false

	if step.target_level_id == Enums.Levels.NONE:
		return false

	# If we're already in the destination level, don't re-commit.
	if GameManager.get_active_level_id() == step.target_level_id:
		if _is_state_machine_ready():
			_apply_hold()
		return true

	var agent_id: StringName = &""
	if _agent_component != null and not String(_agent_component.agent_id).is_empty():
		agent_id = _agent_component.agent_id
	elif _npc.agent_component != null:
		agent_id = _npc.agent_component.agent_id

	if String(agent_id).is_empty():
		# This can happen if the NPC config hasn't been applied yet (manual NPCs).
		# Return false so we retry on the next tick.
		return false

	AgentRegistry.commit_travel_by_id(agent_id, step.target_level_id, step.target_spawn_id)
	AgentRegistry.save_to_session()
	if AgentSpawner != null:
		AgentSpawner.sync_agents_for_active_level()
	return true

## Pure helper: resolve a schedule at a given minute.
static func resolve(schedule: NpcSchedule, minute_of_day: int) -> Resolved:
	var out := Resolved.new()
	out.minute_of_day = _normalize_minute(minute_of_day)
	if schedule == null or schedule.steps.is_empty():
		return out

	# 1) Strict window match: [start, start+duration).
	for i in range(schedule.steps.size()):
		var step: NpcScheduleStep = schedule.steps[i]
		if step == null or not step.is_valid():
			continue
		var start: int = clampi(step.start_minute_of_day, 0, _MINUTES_PER_DAY - 1)
		var end: int = start + max(1, step.duration_minutes)
		if _is_minute_in_range(out.minute_of_day, start, end):
			out.step = step
			out.step_index = i
			out.progress = _compute_progress(out.minute_of_day, start, end)

	return out

static func _normalize_minute(m: int) -> int:
	var mm := m % _MINUTES_PER_DAY
	if mm < 0:
		mm += _MINUTES_PER_DAY
	return mm

static func _is_minute_in_range(m: int, start: int, end: int) -> bool:
	# Range is [start, end) and may wrap across midnight.
	if end <= _MINUTES_PER_DAY:
		return m >= start and m < end
	var wrapped_end := end % _MINUTES_PER_DAY
	return m >= start or m < wrapped_end

static func _compute_progress(m: int, start: int, end: int) -> float:
	var dur: int = max(1, end - start)
	var elapsed: int = 0
	if end <= _MINUTES_PER_DAY:
		elapsed = clampi(m - start, 0, dur)
	else:
		# Wrap case.
		if m >= start:
			elapsed = m - start
		else:
			elapsed = (_MINUTES_PER_DAY - start) + m
		elapsed = clampi(elapsed, 0, dur)
	return clampf(float(elapsed) / float(dur), 0.0, 1.0)

