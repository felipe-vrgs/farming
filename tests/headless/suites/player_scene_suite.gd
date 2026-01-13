extends RefCounted

## Regression: Player scene must produce ToolVisuals so equipped tools render.

const _PLAYER_SCENE := "res://game/entities/player/player.tscn"


func register(runner: Node) -> void:
	runner.add_test(
		"player_scene_has_tool_visuals",
		func() -> void:
			runner._assert_true(ResourceLoader.exists(_PLAYER_SCENE), "Missing Player scene")
			if not ResourceLoader.exists(_PLAYER_SCENE):
				return

			var ps := load(_PLAYER_SCENE) as PackedScene
			runner._assert_true(ps != null, "Failed to load Player PackedScene")
			if ps == null:
				return

			var p := ps.instantiate() as Node
			runner._assert_true(p != null, "Failed to instantiate Player")
			if p == null:
				return

			# Add to tree so Player._ready runs and can self-heal missing ToolVisuals.
			runner.get_tree().root.add_child(p)
			await runner.get_tree().process_frame

			var tool_layer := p.get_node_or_null(NodePath("CharacterVisual/ToolLayer"))
			runner._assert_true(tool_layer != null, "Player missing CharacterVisual/ToolLayer")
			var tv := p.get_node_or_null(NodePath("CharacterVisual/ToolLayer/ToolVisuals"))
			runner._assert_true(tv != null, "Player missing CharacterVisual/ToolLayer/ToolVisuals")

			p.queue_free()
			await runner.get_tree().process_frame
	)
