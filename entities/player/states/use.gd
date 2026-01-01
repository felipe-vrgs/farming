extends PlayerState

var _did_use: bool = false

func enter() -> void:
	super.enter()
	_did_use = false
	if player:
		player.velocity = Vector2.ZERO

func process_frame(_delta: float) -> StringName:
	if _did_use:
		return PlayerStateNames.IDLE
	_did_use = true

	if player.raycell_component == null or not is_instance_valid(player.raycell_component):
		return PlayerStateNames.IDLE

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
			ctx.cell = TileMapManager.global_to_cell(ctx.hit_world_pos)
			if WorldGrid.try_interact_target(ctx, target):
				return PlayerStateNames.IDLE

	# 2) Fallback to grid-based interaction
	var v: Variant = player.raycell_component.get_front_cell()
	if v == null or not (v is Vector2i):
		return PlayerStateNames.IDLE
	ctx.cell = v as Vector2i

	WorldGrid.try_interact(ctx)
	return PlayerStateNames.IDLE

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

