extends Control

signal done(profile: Dictionary, cancelled: bool)

const _DEFAULT_SHIRT_ID: StringName = &"shirt_red_blue"
const _DEFAULT_PANTS_ID: StringName = &"jeans"
const _DEFAULT_SHOES_ID: StringName = &"shoes_brown"
const _DEFAULT_SHIRT_VARIANT: StringName = &"red_blue"
const _DEFAULT_PANTS_VARIANT: StringName = &"jeans"

@onready var preview_visual: CharacterVisual = %PreviewVisual
@onready var preview_margin: Control = %PreviewMargin
@onready var name_edit: LineEdit = %NameEdit
@onready var sex_option: OptionButton = %SexOption
@onready var skin_swatches: GridContainer = %SkinSwatches
@onready var eye_r: HSlider = %EyeR
@onready var eye_g: HSlider = %EyeG
@onready var eye_b: HSlider = %EyeB
@onready var eye_r_value: Label = %EyeRValue
@onready var eye_g_value: Label = %EyeGValue
@onready var eye_b_value: Label = %EyeBValue
@onready var eye_preview: ColorRect = %EyePreview

@onready var hair_r: HSlider = %HairR
@onready var hair_g: HSlider = %HairG
@onready var hair_b: HSlider = %HairB
@onready var hair_r_value: Label = %HairRValue
@onready var hair_g_value: Label = %HairGValue
@onready var hair_b_value: Label = %HairBValue
@onready var hair_preview: ColorRect = %HairPreview
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

var _appearance: CharacterAppearance = null
var _skin_group: ButtonGroup = null
var _suppress_rgb_signals: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Defaults
	_appearance = CharacterAppearance.new()
	_appearance.legs_variant = &"default"
	_appearance.shoes_variant = &"brown"
	_appearance.torso_variant = &"default"
	_appearance.hands_variant = &"default"
	_appearance.hair_variant = &"mohawk"
	_appearance.face_variant = &"male"
	# Palette defaults (match the sprite key palette, but will be changed by UI).
	_appearance.skin_color = CharacterPalettes.DEFAULT_SKIN_MAIN
	_appearance.skin_color_secondary = CharacterPalettes.DEFAULT_SKIN_SECONDARY
	_appearance.eye_color = CharacterPalettes.DEFAULT_EYE
	_appearance.hair_color = CharacterPalettes.DEFAULT_HAIR_BASE
	# Show default clothes in preview (game equips them via equipment).
	_appearance.shirt_variant = _DEFAULT_SHIRT_VARIANT
	_appearance.pants_variant = _DEFAULT_PANTS_VARIANT

	if preview_visual != null:
		preview_visual.process_mode = Node.PROCESS_MODE_ALWAYS
		preview_visual.appearance = _appearance
		preview_visual.play_resolved(&"idle_front")
		_layout_preview()

	if preview_margin != null:
		# Center/scale the Node2D preview inside the Control layout.
		if not preview_margin.resized.is_connected(_layout_preview):
			preview_margin.resized.connect(_layout_preview)

	if sex_option != null:
		sex_option.clear()
		sex_option.add_item("Male", 0)
		sex_option.add_item("Female", 1)
		sex_option.selected = 0
		sex_option.item_selected.connect(_on_any_changed)
	_build_skin_swatches()
	_setup_eye_rgb()
	_setup_hair_rgb()
	if name_edit != null:
		name_edit.text = "Player"
		name_edit.text_changed.connect(_on_any_changed)
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_update_confirm_enabled()
	call_deferred("_focus_name")


func _build_skin_swatches() -> void:
	if skin_swatches == null:
		return

	# Clear existing children (if the scene is hot-reloaded).
	for c in skin_swatches.get_children():
		c.queue_free()

	_skin_group = ButtonGroup.new()

	var selected_idx := _find_matching_skin_preset_index(
		_appearance.skin_color, _appearance.skin_color_secondary
	)

	for i in range(CharacterPalettes.skin_tone_count()):
		var b := Button.new()
		b.text = ""
		b.toggle_mode = true
		b.button_group = _skin_group
		b.custom_minimum_size = Vector2(22, 22)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = CharacterPalettes.skin_tone_name(i)

		var col := CharacterPalettes.skin_main(i)
		var normal := _make_swatch_style(col, Color(0, 0, 0, 0.35), 1)
		var hover := _make_swatch_style(col.lightened(0.06), Color(1, 1, 1, 0.45), 1)
		var pressed := _make_swatch_style(col, Color(1, 1, 1, 0.9), 2)
		var focus := _make_swatch_style(col, Color(1, 1, 1, 0.9), 2)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("focus", focus)

		b.toggled.connect(
			func(pressed_state: bool) -> void:
				if pressed_state:
					_on_skin_preset_selected(i)
		)

		skin_swatches.add_child(b)

		if i == selected_idx:
			b.button_pressed = true


func _make_swatch_style(fill: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	return s


func _find_matching_skin_preset_index(main: Color, secondary: Color) -> int:
	for i in range(CharacterPalettes.skin_tone_count()):
		if (
			CharacterPalettes.skin_main(i) == main
			and CharacterPalettes.skin_secondary(i) == secondary
		):
			return i
	return 0


func _focus_name() -> void:
	if name_edit == null:
		return
	if not name_edit.is_inside_tree():
		return
	name_edit.grab_focus()
	name_edit.caret_column = name_edit.text.length()


func _update_confirm_enabled() -> void:
	if confirm_button == null:
		return
	var n := _get_sanitized_name()
	confirm_button.disabled = n.is_empty()


func _on_skin_preset_selected(idx: int) -> void:
	if _appearance == null:
		return
	_appearance.skin_color = CharacterPalettes.skin_main(idx)
	_appearance.skin_color_secondary = CharacterPalettes.skin_secondary(idx)
	# CharacterVisual listens to appearance.changed; ensure it fires for runtime edits.
	_appearance.emit_changed()
	_refresh_preview()


func _setup_eye_rgb() -> void:
	if eye_r == null or eye_g == null or eye_b == null:
		return
	eye_r.value_changed.connect(_on_eye_rgb_any_changed)
	eye_g.value_changed.connect(_on_eye_rgb_any_changed)
	eye_b.value_changed.connect(_on_eye_rgb_any_changed)

	_suppress_rgb_signals = true
	_set_sliders_from_color(_appearance.eye_color, eye_r, eye_g, eye_b)
	_suppress_rgb_signals = false
	_apply_eye_rgb_to_model()


func _setup_hair_rgb() -> void:
	if hair_r == null or hair_g == null or hair_b == null:
		return
	hair_r.value_changed.connect(_on_hair_rgb_any_changed)
	hair_g.value_changed.connect(_on_hair_rgb_any_changed)
	hair_b.value_changed.connect(_on_hair_rgb_any_changed)

	_suppress_rgb_signals = true
	_set_sliders_from_color(_appearance.hair_color, hair_r, hair_g, hair_b)
	_suppress_rgb_signals = false
	_apply_hair_rgb_to_model()


func _set_sliders_from_color(c: Color, r: HSlider, g: HSlider, b: HSlider) -> void:
	if r != null:
		r.value = int(round(c.r * 255.0))
	if g != null:
		g.value = int(round(c.g * 255.0))
	if b != null:
		b.value = int(round(c.b * 255.0))


func _on_eye_rgb_any_changed(_v: float) -> void:
	if _suppress_rgb_signals:
		return
	_apply_eye_rgb_to_model()


func _on_hair_rgb_any_changed(_v: float) -> void:
	if _suppress_rgb_signals:
		return
	_apply_hair_rgb_to_model()


func _apply_eye_rgb_to_model() -> void:
	if _appearance == null:
		return
	var c := _color_from_sliders(eye_r, eye_g, eye_b)
	_appearance.eye_color = c
	_appearance.emit_changed()
	_update_rgb_labels(eye_r, eye_g, eye_b, eye_r_value, eye_g_value, eye_b_value, eye_preview)
	_refresh_preview()


func _apply_hair_rgb_to_model() -> void:
	if _appearance == null:
		return
	var c := _color_from_sliders(hair_r, hair_g, hair_b)
	_appearance.hair_color = c
	_appearance.emit_changed()
	_update_rgb_labels(
		hair_r, hair_g, hair_b, hair_r_value, hair_g_value, hair_b_value, hair_preview
	)
	_refresh_preview()


func _color_from_sliders(r: HSlider, g: HSlider, b: HSlider) -> Color:
	var rr := 0
	var gg := 0
	var bb := 0
	if r != null:
		rr = int(round(r.value))
	if g != null:
		gg = int(round(g.value))
	if b != null:
		bb = int(round(b.value))
	return Color8(rr, gg, bb, 255)


func _update_rgb_labels(
	r: HSlider,
	g: HSlider,
	b: HSlider,
	r_label: Label,
	g_label: Label,
	b_label: Label,
	preview: ColorRect
) -> void:
	if r_label != null and r != null:
		r_label.text = str(int(round(r.value)))
	if g_label != null and g != null:
		g_label.text = str(int(round(g.value)))
	if b_label != null and b != null:
		b_label.text = str(int(round(b.value)))
	if preview != null:
		preview.color = _color_from_sliders(r, g, b)


func _on_any_changed(_v: Variant = null) -> void:
	if _appearance == null:
		return
	# Sex drives face variant for now.
	var idx := 0
	if sex_option != null:
		idx = int(sex_option.selected)
	_appearance.face_variant = &"female" if idx == 1 else &"male"
	_appearance.emit_changed()
	_refresh_preview()
	_update_confirm_enabled()


func _refresh_preview() -> void:
	if preview_visual == null:
		return
	preview_visual.appearance = _appearance
	preview_visual.play_resolved(&"idle_front")


func _on_confirm_pressed() -> void:
	var profile := _build_profile(false)
	done.emit(profile, false)
	visible = false


func _on_cancel_pressed() -> void:
	done.emit({}, true)
	visible = false


func _get_sanitized_name() -> String:
	var name := "Player"
	if name_edit != null:
		name = String(name_edit.text).strip_edges()
	return name


func _build_profile(_for_preview: bool) -> Dictionary:
	var name := _get_sanitized_name()
	if name.is_empty():
		name = "Player"

	var equip := PlayerEquipment.new()
	equip.set_equipped_item_id(EquipmentSlots.SHIRT, _DEFAULT_SHIRT_ID)
	equip.set_equipped_item_id(EquipmentSlots.PANTS, _DEFAULT_PANTS_ID)
	equip.set_equipped_item_id(EquipmentSlots.SHOES, _DEFAULT_SHOES_ID)

	return {
		"display_name": name,
		"appearance": _appearance,
		"equipment": equip,
	}


func _layout_preview() -> void:
	# CharacterVisual is a Node2D; Controls won't auto-layout it. Center it manually.
	if preview_visual == null or preview_margin == null:
		return

	var area := preview_margin.size
	if area.x <= 0.0 or area.y <= 0.0:
		return

	# Avoid subpixel placement; helps keep pixel art crisp (no sampling jitter).
	preview_visual.position = (area * 0.5).floor()
	preview_visual.scale = Vector2(3, 3)
