@tool
extends DialogicEvent

## Restore one or more agents to their pre-cutscene snapshot captured by DialogueManager.
## This is an explicit action; if the timeline doesn't call it, no auto-restore happens.
##
## Agent ids are provided as a comma-separated string (e.g. "player,frieren").
var agent_ids: String = "player"
var auto_blackout: bool = false
var blackout_time: float = 0.25
## If true (recommended for end-of-cutscene restores), schedule blackout+restore to run
## AFTER the timeline ends (handled by DialogueManager). This avoids textbox/UI flicker.
var defer_to_timeline_end: bool = true

func _blackout_begin() -> void:
	if UIManager == null or not UIManager.has_method("blackout_begin"):
		return
	if DialogueManager != null:
		DialogueManager.set_layout_visible(false)
	await UIManager.blackout_begin(maxf(0.0, blackout_time))

func _blackout_end() -> void:
	if UIManager == null or not UIManager.has_method("blackout_end"):
		return
	if DialogueManager != null:
		DialogueManager.set_layout_visible(false)
	await UIManager.blackout_end(maxf(0.0, blackout_time))
	if dialogic != null:
		await dialogic.get_tree().process_frame
	if DialogueManager != null:
		DialogueManager.set_layout_visible(true)

func _execute() -> void:
	if DialogueManager == null:
		push_warning("RestoreAgents: DialogueManager restore API not available.")
		finish()
		return

	if agent_ids.strip_edges().is_empty():
		push_warning("RestoreAgents: agent_ids is empty.")
		finish()
		return

	# Preferred: schedule restore to run AFTER the timeline ends. This prevents a common flicker:
	# auto-blackout fades back in while the Dialogic layout still exists, then the timeline ends.
	if defer_to_timeline_end:
		var ids := PackedStringArray()
		for raw in agent_ids.split(",", false):
			var t := raw.strip_edges()
			if not t.is_empty():
				ids.append(t)
		if not ids.is_empty():
			DialogueManager.queue_cutscene_restore_after_timeline(ids, auto_blackout, blackout_time)
		finish()
		return

	dialogic.current_state = dialogic.States.WAITING
	if auto_blackout:
		await _blackout_begin()

	for raw in agent_ids.split(",", false):
		var t := raw.strip_edges()
		if t.is_empty():
			continue
		await DialogueManager.restore_cutscene_agent_snapshot(StringName(t))

	if auto_blackout:
		await _blackout_end()

	dialogic.current_state = dialogic.States.IDLE
	finish()

func _init() -> void:
	event_name = "Restore Agents"
	set_default_color("Color7")
	event_category = "Agent"
	event_sorting_index = 5

func get_shortcode() -> String:
	# Keep shortcode stable for existing timelines.
	return "cutscene_restore_actors"

func get_shortcode_parameters() -> Dictionary:
	return {
		"agent_ids": {"property": "agent_ids", "default": "player"},
		"auto_blackout": {"property": "auto_blackout", "default": false},
		"blackout_time": {"property": "blackout_time", "default": 0.25},
		"defer": {"property": "defer_to_timeline_end", "default": true},
	}

func build_event_editor() -> void:
	add_header_label("Restore agents")
	add_header_edit(
		"agent_ids",
		ValueType.SINGLELINE_TEXT,
		{"placeholder":"Comma-separated ids (player,frieren,...)"}
	)
	add_body_edit("auto_blackout", ValueType.BOOL, {"left_text":"Auto blackout:"})
	add_body_edit("blackout_time",
		ValueType.NUMBER,
		{"left_text":"Blackout time (s):", "min":0.0},
		"auto_blackout"
	)
	add_body_edit("defer_to_timeline_end",
		ValueType.BOOL,
		{"left_text":"Defer to timeline end:", "default": true},
		"auto_blackout"
	)
