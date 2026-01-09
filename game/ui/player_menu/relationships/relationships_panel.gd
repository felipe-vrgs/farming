@tool
class_name RelationshipsPanel
extends MarginContainer

const _HEARTS_ATLAS: Texture2D = preload("res://assets/icons/heart.png")
const _PORTRAIT_SCENE: PackedScene = preload(
	"res://game/ui/player_menu/relationships/npc_portrait.tscn"
)

const _NPC_ICON_SIZE := Vector2(24, 24)
const _HEART_SIZE := Vector2(16, 16)
const _HEART_SLOTS := 10

const _HEART_TILE_SIZE := Vector2i(16, 16)
const _HEART_FULL_REGION := Rect2i(Vector2i(0, 0), _HEART_TILE_SIZE)
const _HEART_HALF_REGION := Rect2i(Vector2i(16, 0), _HEART_TILE_SIZE)
const _HEART_EMPTY_REGION := Rect2i(Vector2i(32, 0), _HEART_TILE_SIZE)

static var _heart_textures_ready: bool = false
static var _tex_heart_empty: Texture2D = null
static var _tex_heart_half: Texture2D = null
static var _tex_heart_full: Texture2D = null

@onready var _list: VBoxContainer = %List

var _rows_by_npc: Dictionary = {}  # npc_id:StringName -> {hearts:Array[TextureRect]}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_heart_textures()

	if OS.get_environment("FARMING_TEST_MODE") == "1":
		refresh()
		return

	if not Engine.is_editor_hint() and EventBus != null:
		if (
			"relationship_changed" in EventBus
			and not EventBus.relationship_changed.is_connected(_on_changed)
		):
			EventBus.relationship_changed.connect(_on_changed)

	refresh()


func _exit_tree() -> void:
	if EventBus == null:
		return
	if (
		"relationship_changed" in EventBus
		and EventBus.relationship_changed.is_connected(_on_changed)
	):
		EventBus.relationship_changed.disconnect(_on_changed)


func rebind() -> void:
	refresh()


func refresh() -> void:
	if _list == null:
		return

	_rows_by_npc.clear()
	for c in _list.get_children():
		c.queue_free()

	if Engine.is_editor_hint():
		var ids := _scan_npc_ids_from_configs()
		if ids.is_empty():
			_list.add_child(_make_placeholder_row("No NPC configs found."))
			return
		for npc_id in ids:
			_add_row(npc_id, 0)
		return

	if RelationshipManager == null:
		_list.add_child(_make_placeholder_row("RelationshipManager unavailable."))
		return

	var npc_ids: Array[StringName] = RelationshipManager.list_npc_ids()
	if npc_ids.is_empty():
		_list.add_child(_make_placeholder_row("No NPCs found."))
		return

	for npc_id in npc_ids:
		var units := int(RelationshipManager.get_units(npc_id))
		_add_row(npc_id, units)


func _on_changed(npc_id: StringName, units: int) -> void:
	_update_row(npc_id, int(units))


func _add_row(npc_id: StringName, units: int) -> void:
	if _list == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.process_mode = Node.PROCESS_MODE_ALWAYS

	# Portrait
	var portrait: NpcPortrait = null
	if _PORTRAIT_SCENE != null:
		var inst := _PORTRAIT_SCENE.instantiate()
		portrait = inst as NpcPortrait
	if portrait == null:
		portrait = NpcPortrait.new()
	portrait.portrait_size = _NPC_ICON_SIZE
	# In-editor, if the portrait scene isn't tool-enabled, it can instantiate as a placeholder.
	# Avoid calling methods on placeholders to prevent editor errors.
	if portrait.has_method("setup_from_npc_id"):
		portrait.call("setup_from_npc_id", npc_id)
	row.add_child(portrait)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = String(npc_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(name_lbl)

	# Hearts
	var hearts_box := HBoxContainer.new()
	hearts_box.add_theme_constant_override("separation", 2)
	hearts_box.alignment = BoxContainer.ALIGNMENT_END
	hearts_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	hearts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts_box.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(hearts_box)

	var hearts: Array[TextureRect] = []
	for _i in range(_HEART_SLOTS):
		var rct := TextureRect.new()
		rct.custom_minimum_size = _HEART_SIZE
		rct.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rct.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rct.process_mode = Node.PROCESS_MODE_ALWAYS
		hearts_box.add_child(rct)
		hearts.append(rct)

	_list.add_child(row)
	_rows_by_npc[npc_id] = {"hearts": hearts}
	_update_row(npc_id, units)


func _update_row(npc_id: StringName, units: int) -> void:
	var row_any: Variant = _rows_by_npc.get(npc_id)
	if row_any == null or not (row_any is Dictionary):
		return
	var hearts: Array = (row_any as Dictionary).get("hearts", [])
	if hearts == null or hearts.is_empty():
		return

	var u := clampi(int(units), 0, 20)
	for i in range(mini(_HEART_SLOTS, hearts.size())):
		var rct: TextureRect = hearts[i] as TextureRect
		if rct == null:
			continue
		var slot_units := clampi(u - (i * 2), 0, 2)
		rct.texture = _tex_for_slot_units(slot_units)


func _tex_for_slot_units(slot_units: int) -> Texture2D:
	if slot_units >= 2:
		return _tex_heart_full
	if slot_units == 1:
		return _tex_heart_half
	return _tex_heart_empty


func _make_placeholder_row(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	return lbl


func _ensure_heart_textures() -> void:
	if _heart_textures_ready:
		return
	_heart_textures_ready = true

	_tex_heart_full = _make_atlas_tex(_HEART_FULL_REGION)
	_tex_heart_half = _make_atlas_tex(_HEART_HALF_REGION)
	_tex_heart_empty = _make_atlas_tex(_HEART_EMPTY_REGION)

	# Fallback: if detection failed, at least show something (full icon may be null).
	if _tex_heart_empty == null:
		_tex_heart_empty = _HEARTS_ATLAS
	if _tex_heart_half == null:
		_tex_heart_half = _HEARTS_ATLAS
	if _tex_heart_full == null:
		_tex_heart_full = _HEARTS_ATLAS


func _make_atlas_tex(region: Rect2i) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = _HEARTS_ATLAS
	at.region = region
	return at


func _scan_npc_ids_from_configs() -> Array[StringName]:
	# Editor/tool fallback: scan configs directly (autoload may not exist in editor).
	var out: Array[StringName] = []
	var dir_path := "res://game/entities/npc/configs"
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	for entry in files:
		if entry.begins_with("."):
			continue
		# Only take actual NPC configs; ignore inventory resources.
		if not entry.ends_with(".tres"):
			continue
		if entry.ends_with("_inventory.tres"):
			continue

		var p := "%s/%s" % [dir_path, entry]
		var res := load(p)
		if res == null:
			continue

		# Be robust in tool scripts: don't rely on `res is NpcConfig` (class load order).
		var id_any: Variant = res.get("npc_id") if res.has_method("get") else null
		var npc_id := id_any as StringName if id_any is StringName else StringName(String(id_any))
		if String(npc_id).is_empty():
			continue
		out.append(npc_id)

	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
