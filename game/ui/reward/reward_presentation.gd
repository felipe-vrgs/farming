class_name RewardPresentation
extends CanvasLayer

## Simple non-interactive overlay that shows a "Press <binding> to continue" prompt.
## Designed to work while SceneTree is paused (GrantRewardState pauses the tree).

@onready var _title: Label = %Title
@onready var _prompt: Label = %Prompt


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_prompt(action: StringName = &"ui_accept", title: String = "NEW ITEM UNLOCKED") -> void:
	if _title != null:
		var t := String(title).strip_edges()
		_title.text = t.to_upper() if not t.is_empty() else ""
		_title.visible = not _title.text.is_empty()
	if _prompt != null:
		_prompt.text = _format_prompt(action)
	visible = true


func hide_prompt() -> void:
	visible = false


func _format_prompt(action: StringName) -> String:
	var binding := _binding_for_action(action)
	if binding.is_empty():
		binding = "Enter"
	return "Press %s to continue" % binding


func _binding_for_action(action: StringName) -> String:
	if String(action).is_empty() or not InputMap.has_action(action):
		return ""

	var key_text := ""

	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			if k.physical_keycode != KEY_NONE:
				key_text = OS.get_keycode_string(k.physical_keycode)
				break

	return key_text if not key_text.is_empty() else ""
