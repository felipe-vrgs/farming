@tool
extends DialogicEvent

## Show an emote bubble above an agent (by id).

const _PRESET_ICON_PATHS := {
	"heart_eyes": "res://assets/icons/emoji_heart_eyes.png",
	"sweat": "res://assets/icons/emoji_sweat.png",
	"puke": "res://assets/icons/emoji_puke.png",
	"talk": "res://assets/icons/talk_bubble.png",
	"zzz": "res://assets/icons/zzz.png",
}

var agent_id: String = "player"
var channel: String = "emote"
var icon_preset: String = "custom"
var icon_path: String = ""
var text: String = ""
var duration: float = 1.0
var show_text: bool = true
var show_panel: bool = true
var scale_factor: float = 1.0


func _execute() -> void:
	if String(agent_id).is_empty():
		push_warning("Emote: agent_id is empty.")
		finish()
		return
	if Runtime == null or not Runtime.has_method("find_agent_by_id"):
		push_warning("Emote: Runtime not available.")
		finish()
		return

	var agent: Node2D = Runtime.find_agent_by_id(StringName(agent_id))
	if agent == null:
		push_warning("Emote: Agent not found: %s" % String(agent_id))
		finish()
		return

	var comp_any := ComponentFinder.find_component_in_group(agent, Groups.EMOTE_COMPONENTS)
	if comp_any != null and comp_any.has_method("show_emote_icon_path"):
		var resolved_path := _resolve_icon_path()
		comp_any.call(
			"show_emote_icon_path",
			StringName(channel),
			resolved_path,
			text,
			float(duration),
			bool(show_text),
			bool(show_panel),
			float(scale_factor)
		)

	finish()


func _init() -> void:
	event_name = "Emote"
	set_default_color("Color7")
	event_category = "Emote"
	event_sorting_index = 0


func get_shortcode() -> String:
	return "emote_show"


func get_shortcode_parameters() -> Dictionary:
	return {
		"agent_id": {"property": "agent_id", "default": "player"},
		"channel": {"property": "channel", "default": "emote"},
		"icon": {"property": "icon_preset", "default": "custom"},
		"icon_path": {"property": "icon_path", "default": ""},
		"text": {"property": "text", "default": ""},
		"duration": {"property": "duration", "default": 1.0},
		"show_text": {"property": "show_text", "default": true},
		"show_panel": {"property": "show_panel", "default": true},
		"scale": {"property": "scale_factor", "default": 1.0},
	}


func build_event_editor() -> void:
	add_header_edit("agent_id", ValueType.DYNAMIC_OPTIONS, {
		"left_text":"Show emote on",
		"autofocus":true,
		"placeholder":"Agent id",
		"mode": 0, # PURE_STRING
		"suggestions_func": CutsceneOptions.get_agent_id_suggestions,
	})
	add_body_edit("channel", ValueType.SINGLELINE_TEXT, {
		"left_text":"Channel:",
		"placeholder":"emote",
	})
	add_body_edit("icon_preset", ValueType.FIXED_OPTIONS, {
		"left_text":"Icon preset:",
		"options": [
			{"label": "Custom", "value": "custom"},
			{"label": "Heart eyes", "value": "heart_eyes"},
			{"label": "Sweat", "value": "sweat"},
			{"label": "Puke", "value": "puke"},
			{"label": "Talk", "value": "talk"},
			{"label": "Zzz", "value": "zzz"},
		],
	})
	add_body_edit("icon_path", ValueType.SINGLELINE_TEXT, {
		"left_text":"Custom icon path:",
		"placeholder":"res://assets/icons/heart.png",
	})
	add_body_edit("text", ValueType.SINGLELINE_TEXT, {
		"left_text":"Text:",
		"placeholder":"...",
	})
	add_body_edit("show_text", ValueType.BOOL, {"left_text":"Show text:"})
	add_body_edit("show_panel", ValueType.BOOL, {"left_text":"Show panel:"})
	add_body_edit("scale_factor", ValueType.NUMBER, {"left_text":"Scale:", "min": 0.5})
	add_body_edit("duration", ValueType.NUMBER, {
		"left_text":"Duration (sec):",
		"min": 0.0,
	})


func _resolve_icon_path() -> String:
	var preset := String(icon_preset).strip_edges()
	if not preset.is_empty() and preset != "custom":
		if _PRESET_ICON_PATHS.has(preset):
			return _PRESET_ICON_PATHS[preset]
		return preset
	return String(icon_path).strip_edges()
