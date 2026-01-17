class_name ContextPromptDriver
extends Node

## Displays context prompts (e.g. "Press E: Shop") on nearby interactables.

@export var default_prompt_icon: Texture2D = preload("res://assets/icons/keyboard/F.tres")

var _player: Player = null
var _last_emote_comp: EmoteComponent = null
var _last_prompt_text: String = ""
var _last_prompt_icon: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = _resolve_player()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	if not _should_show_prompts():
		_clear_prompt()
		return
	if _player.raycell_component == null or not is_instance_valid(_player.raycell_component):
		_clear_prompt()
		return

	var result := _resolve_prompt_target()
	if result.is_empty():
		_clear_prompt()
		return

	var comp: EmoteComponent = result.get("emote_component")
	var icon: Texture2D = result.get("icon")
	var text: String = result.get("text", "")
	if comp == null or not is_instance_valid(comp) or text.is_empty():
		_clear_prompt()
		return

	var formatted := _format_prompt_text(text)
	if comp == _last_emote_comp and formatted == _last_prompt_text and icon == _last_prompt_icon:
		return

	_clear_prompt()
	comp.show_emote(&"prompt", icon, formatted, 0.0)
	_last_emote_comp = comp
	_last_prompt_text = formatted
	_last_prompt_icon = icon


func _resolve_prompt_target() -> Dictionary:
	var best: Dictionary = {}

	# 1) Raycast colliders (closest to the player).
	for hit in _player.raycell_component.get_use_colliders():
		var target := _resolve_interactable_target(hit)
		if target == null:
			continue
		var entry := _get_best_prompt_for_entity(target)
		if entry.is_empty():
			continue
		if _is_better_prompt(entry, best):
			best = entry

	# 2) Fallback to grid cell query.
	if best.is_empty():
		var cell_v: Variant = _player.raycell_component.get_front_cell_magnetized()
		if cell_v is Vector2i:
			var ctx_cell: Vector2i = cell_v
			var q: Variant = WorldGrid.query_interactables_at(ctx_cell)
			if q != null and "entities" in q:
				for entity in q.entities:
					if entity == null:
						continue
					var entry2 := _get_best_prompt_for_entity(entity, ctx_cell)
					if entry2.is_empty():
						continue
					if _is_better_prompt(entry2, best):
						best = entry2

	return best


func _resolve_player() -> Player:
	var p: Node = get_parent()
	if p == null:
		return null
	if StringName(p.name) == &"Components":
		p = p.get_parent()
	if p is Player:
		return p as Player
	if owner is Player:
		return owner as Player
	return null


func _should_show_prompts() -> bool:
	if Runtime == null or Runtime.game_flow == null:
		return true
	var state: StringName = Runtime.game_flow.get_active_state()
	return state == GameStateNames.IN_GAME


func _get_best_prompt_for_entity(entity: Node, cell: Vector2i = Vector2i.ZERO) -> Dictionary:
	if entity == null:
		return {}

	var emote_any := ComponentFinder.find_component_in_group(entity, Groups.EMOTE_COMPONENTS)
	var emote := emote_any as EmoteComponent
	if emote == null:
		return {}

	var ctx := InteractionContext.new()
	ctx.kind = InteractionContext.Kind.USE
	ctx.actor = _player
	ctx.target = entity
	ctx.cell = cell
	if entity is Node2D:
		ctx.hit_world_pos = (entity as Node2D).global_position

	var best: Dictionary = {}
	var comps := ComponentFinder.find_components_in_group(entity, Groups.INTERACTABLE_COMPONENTS)
	for comp_any in comps:
		if comp_any == null:
			continue
		var comp := comp_any as InteractableComponent
		if comp == null:
			continue
		if not comp.has_method("get_prompt_text"):
			continue
		var label := String(comp.get_prompt_text(ctx)).strip_edges()
		if label.is_empty():
			continue
		var icon: Texture2D = null
		if comp.has_method("get_prompt_icon"):
			var icon_any := comp.get_prompt_icon(ctx)
			if icon_any is Texture2D:
				icon = icon_any as Texture2D
		if icon == null and default_prompt_icon != null:
			icon = default_prompt_icon
		var prio := comp.get_priority()
		var entry := {
			"priority": prio,
			"text": label,
			"icon": icon,
			"emote_component": emote,
		}
		if _is_better_prompt(entry, best):
			best = entry

	return best


func _resolve_interactable_target(hit: Node) -> Node:
	var n: Node = hit
	for _i in range(8):
		if n == null:
			return null
		var comps := ComponentFinder.find_components_in_group(n, Groups.INTERACTABLE_COMPONENTS)
		if not comps.is_empty():
			return n
		n = n.get_parent()
	return null


func _is_better_prompt(candidate: Dictionary, best: Dictionary) -> bool:
	if best.is_empty():
		return true
	return int(candidate.get("priority", 0)) > int(best.get("priority", 0))


func _format_prompt_text(label: String) -> String:
	return label


func _get_interact_action() -> StringName:
	if _player != null and _player.player_input_config != null:
		return _player.player_input_config.action_interact
	return &"interact"


func _get_first_key_label(action: StringName) -> String:
	if String(action).is_empty() or not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			if k.physical_keycode != KEY_NONE:
				return OS.get_keycode_string(k.physical_keycode)
	return ""


func _clear_prompt() -> void:
	if _last_emote_comp != null and is_instance_valid(_last_emote_comp):
		_last_emote_comp.clear(&"prompt")
	_last_emote_comp = null
	_last_prompt_text = ""
	_last_prompt_icon = null
