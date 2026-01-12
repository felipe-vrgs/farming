class_name RewardPresentation
extends CanvasLayer

## Simple non-interactive overlay that shows a "Press <binding> to continue" prompt.
## Designed to work while SceneTree is paused (GrantRewardState pauses the tree).

const _CONFETTI_CONFIG: ParticleConfig = preload(
	"res://game/entities/particles/resources/ui_reward_confetti.tres"
)
const _SPARKLE_CONFIG: ParticleConfig = preload(
	"res://game/entities/particles/resources/ui_reward_sparkle.tres"
)

@onready var _title: Label = %Title
@onready var _prompt: Label = %Prompt
@onready var _vignette: ColorRect = get_node_or_null("Root/Vignette") as ColorRect
@onready var _confetti_vfx: VFX = get_node_or_null("Root/ConfettiVFX") as VFX
@onready var _sparkle_vfx: VFX = get_node_or_null("Root/SparkleVFX") as VFX

var _show_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if _confetti_vfx != null:
		_confetti_vfx.setup(_CONFETTI_CONFIG)
	if _sparkle_vfx != null:
		_sparkle_vfx.setup(_SPARKLE_CONFIG)


func show_prompt(action: StringName = &"ui_accept", title: String = "NEW ITEM UNLOCKED") -> void:
	if _title != null:
		var t := String(title).strip_edges()
		_title.text = t.to_upper() if not t.is_empty() else ""
		_title.visible = not _title.text.is_empty()
	if _prompt != null:
		_prompt.text = _format_prompt(action)
	visible = true
	call_deferred("_play_show_animation")
	call_deferred("_play_party_effects")


func hide_prompt() -> void:
	if _show_tween != null and is_instance_valid(_show_tween):
		_show_tween.kill()
		_show_tween = null
	visible = false


func _play_show_animation() -> void:
	# Punchy "WOW" entrance that still runs while paused.
	if _show_tween != null and is_instance_valid(_show_tween):
		_show_tween.kill()
		_show_tween = null

	await get_tree().process_frame
	if not visible:
		return

	if _title != null:
		_title.pivot_offset = _title.size * 0.5
		_title.modulate.a = 0.0
		_title.scale = Vector2(0.90, 0.90)
		_title.rotation = -0.06
	if _prompt != null:
		_prompt.pivot_offset = _prompt.size * 0.5
		_prompt.modulate.a = 0.0
		_prompt.scale = Vector2(0.98, 0.98)
	if _vignette != null:
		_vignette.modulate.a = 0.0

	_show_tween = create_tween()
	_show_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_show_tween.set_parallel(true)

	# Subtle vignette punch-in.
	if _vignette != null:
		(
			_show_tween
			. tween_property(_vignette, "modulate:a", 1.0, 0.18)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)

	# Title bounce + tiny wobble.
	if _title != null:
		(
			_show_tween
			. tween_property(_title, "modulate:a", 1.0, 0.12)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_show_tween
			. tween_property(_title, "scale", Vector2(1.08, 1.08), 0.16)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_show_tween
			. tween_property(_title, "rotation", 0.04, 0.16)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)

	# Prompt comes in a beat later.
	if _prompt != null:
		(
			_show_tween
			. tween_property(_prompt, "modulate:a", 1.0, 0.18)
			. set_delay(0.18)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_show_tween
			. tween_property(_prompt, "scale", Vector2.ONE, 0.22)
			. set_delay(0.18)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)

	_show_tween.set_parallel(false)

	# Settle title back to rest.
	if _title != null:
		(
			_show_tween
			. tween_property(_title, "scale", Vector2.ONE, 0.12)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_show_tween
			. parallel()
			. tween_property(_title, "rotation", 0.0, 0.12)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)


func _play_party_effects() -> void:
	# Keep headless tests deterministic and avoid UI node churn/leaks.
	if OS.get_environment("FARMING_TEST_MODE") == "1":
		return
	# Let layout settle so label sizes/positions are valid.
	await get_tree().process_frame
	if not visible:
		return

	var rect := get_viewport().get_visible_rect()
	var top_center := rect.position + Vector2(rect.size.x * 0.5, 0.0)

	if _confetti_vfx != null and is_instance_valid(_confetti_vfx):
		_confetti_vfx.play(top_center, 200)

	var sparkle_pos := rect.position + (rect.size * 0.5)
	if _title != null and is_instance_valid(_title):
		sparkle_pos = _title.global_position + (_title.size * 0.5)
	if _sparkle_vfx != null and is_instance_valid(_sparkle_vfx):
		_sparkle_vfx.play(sparkle_pos, 210)


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
