@tool
extends DialogicEvent

## Wait until one or more active cutscene move tweens finish.
## Use actor_ids="*" to wait for all active move tweens.
const _MOVE_TWEEN_META_KEY := &"dialogic_additions_cutscene_move_tweens"

var actor_ids: String = "*"

func _get_move_tween_map() -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop == null:
		return {}
	if not loop.has_meta(_MOVE_TWEEN_META_KEY):
		return {}
	var d := loop.get_meta(_MOVE_TWEEN_META_KEY)
	return d if d is Dictionary else {}

func _execute() -> void:
	if dialogic == null:
		finish()
		return

	dialogic.current_state = dialogic.States.WAITING

	var wanted := PackedStringArray()
	var raw := actor_ids.strip_edges()
	if raw == "*" or raw.is_empty():
		# Wait for all.
		wanted = PackedStringArray()
	else:
		for s in raw.split(",", false):
			var t := s.strip_edges()
			if not t.is_empty():
				wanted.append(t)

	while true:
		var m := _get_move_tween_map()
		if raw == "*" or raw.is_empty():
			if m.is_empty():
				break
		else:
			var any_left := false
			for id in wanted:
				var tw := m.get(id)
				if tw is Tween and is_instance_valid(tw):
					any_left = true
					break
			if not any_left:
				break

		await dialogic.get_tree().process_frame

	dialogic.current_state = dialogic.States.IDLE
	finish()

func _init() -> void:
	event_name = "Wait For Moves"
	set_default_color("Color7")
	event_category = "Cutscene"
	event_sorting_index = 6

func get_shortcode() -> String:
	return "cutscene_wait_for_moves"

func get_shortcode_parameters() -> Dictionary:
	return {
		"actor_ids": {"property": "actor_ids", "default": "*"},
	}

func build_event_editor() -> void:
	add_header_label("Wait for moves")
	add_header_edit("actor_ids", ValueType.SINGLELINE_TEXT, {
		"placeholder":"* or comma-separated (player,frieren,...)"
	})

