extends Control

signal done(profile: Dictionary, cancelled: bool)

const _DEFAULT_SHIRT_ID: StringName = &"shirt_red_blue"
const _DEFAULT_PANTS_ID: StringName = &"pants_brown"
const _DEFAULT_SHIRT_VARIANT: StringName = &"red_blue"
const _DEFAULT_PANTS_VARIANT: StringName = &"brown"

@onready var preview_visual: CharacterVisual = %PreviewVisual
@onready var preview_margin: Control = %PreviewMargin
@onready var name_edit: LineEdit = %NameEdit
@onready var sex_option: OptionButton = %SexOption
@onready var skin_picker: ColorPickerButton = %SkinPicker
@onready var eye_picker: ColorPickerButton = %EyePicker
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

var _appearance: CharacterAppearance = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Defaults
	_appearance = CharacterAppearance.new()
	_appearance.legs_variant = &"default"
	_appearance.torso_variant = &"default"
	_appearance.hands_top_variant = &"default"
	_appearance.hair_variant = &"mohawk"
	_appearance.face_variant = &"male"
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
	if skin_picker != null:
		skin_picker.color = _appearance.skin_color
		skin_picker.color_changed.connect(_on_skin_changed)
	if eye_picker != null:
		eye_picker.color = _appearance.eye_color
		eye_picker.color_changed.connect(_on_eye_changed)
	if name_edit != null:
		name_edit.text = "Player"
		name_edit.text_changed.connect(_on_any_changed)
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_update_confirm_enabled()
	call_deferred("_focus_name")


func _focus_name() -> void:
	if name_edit == null:
		return
	name_edit.grab_focus()
	name_edit.caret_column = name_edit.text.length()


func _update_confirm_enabled() -> void:
	if confirm_button == null:
		return
	var n := _get_sanitized_name()
	confirm_button.disabled = n.is_empty()


func _on_skin_changed(c: Color) -> void:
	if _appearance == null:
		return
	_appearance.skin_color = c
	_refresh_preview()


func _on_eye_changed(c: Color) -> void:
	if _appearance == null:
		return
	_appearance.eye_color = c
	_refresh_preview()


func _on_any_changed(_v: Variant = null) -> void:
	if _appearance == null:
		return
	# Sex drives face variant for now.
	var idx := 0
	if sex_option != null:
		idx = int(sex_option.selected)
	_appearance.face_variant = &"female" if idx == 1 else &"male"
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

	preview_visual.position = area * 0.5

	# Pixel-art friendly integer scaling. Base frames are 32px.
	var target := minf(area.x, area.y)
	var s := clampi(int(target / 48.0), 2, 6)
	preview_visual.scale = Vector2(float(s), float(s))
