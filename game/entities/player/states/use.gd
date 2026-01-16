extends PlayerState

var _did_use: bool = false


func enter() -> void:
	super.enter()
	_did_use = false
	if player:
		player.velocity = Vector2.ZERO


func process_frame(_delta: float) -> StringName:
	if _did_use:
		return _resolve_post_use_state()
	_did_use = true

	if player.raycell_component == null or not is_instance_valid(player.raycell_component):
		return _resolve_post_use_state()

	var ctx := InteractionContext.new()
	ctx.kind = InteractionContext.Kind.USE
	ctx.actor = player
	ctx.tool_data = null

	# Prefer direct "use" target via raycast (NPCs/doors/etc).
	# 1) Thick cast (more forgiving).
	for hit in player.raycell_component.get_use_colliders():
		var target := _resolve_interactable_target(hit)
		if target != null:
			ctx.target = target
			ctx.hit_world_pos = target.global_position
			ctx.cell = WorldGrid.tile_map.global_to_cell(ctx.hit_world_pos)
			if WorldGrid.try_interact_target(ctx, target):
				return _resolve_post_use_state()

	# 2) Fallback to grid-based interaction
	var v: Variant = player.raycell_component.get_front_cell_magnetized()
	if v == null or not (v is Vector2i):
		return _resolve_post_use_state()
	ctx.cell = v as Vector2i

	WorldGrid.try_interact(ctx)
	return _resolve_post_use_state()


func _resolve_interactable_target(hit: Node) -> Node:
	# The raycast may hit a collider (e.g. StaticBody2D) under an entity root.
	# Walk up a bit to find a node that owns InteractableComponents.
	var n: Node = hit
	for _i in range(8):
		if n == null:
			return null
		var comps := ComponentFinder.find_components_in_group(n, Groups.INTERACTABLE_COMPONENTS)
		if not comps.is_empty():
			return n
		n = n.get_parent()
	return null


func _resolve_post_use_state() -> StringName:
	if (
		player != null
		and player.tool_manager != null
		and player.tool_manager.has_method("is_in_item_mode")
	):
		if bool(player.tool_manager.call("is_in_item_mode")):
			return PlayerStateNames.PLACEMENT
	return PlayerStateNames.IDLE
