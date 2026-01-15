@tool
extends DialogicEvent

## Set the Frieren house tier (shared with exterior).

var tier: int = 0


func _execute() -> void:
	if Runtime == null or not Runtime.has_method("set_frieren_house_tier"):
		push_warning("House Tier: Runtime not available.")
		finish()
		return
	Runtime.set_frieren_house_tier(int(tier))
	finish()


func _init() -> void:
	event_name = "Set House Tier"
	set_default_color("Color7")
	event_category = "House"
	event_sorting_index = 0


func get_shortcode() -> String:
	return "house_tier_set"


func get_shortcode_parameters() -> Dictionary:
	return {
		"tier": {"property": "tier", "default": 0},
	}


func build_event_editor() -> void:
	add_header_label("Set house tier")
	add_header_edit(
		"tier",
		ValueType.NUMBER,
		{
			"placeholder": "tier (default 0)",
		}
	)
