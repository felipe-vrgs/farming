extends RefCounted

## Regression: character creation shirt/pants selections must be reflected in starting equipment.
## - If the selected variant is empty, the slot should start unequipped.
## - Shoes are currently not selectable in character creation and should remain default-equipped.

const _PLAYER_SCENE := "res://game/entities/player/player.tscn"
const _SCREEN_SCRIPT := "res://game/ui/character_creation/character_creation_screen.gd"


func register(runner: Node) -> void:
	runner.add_test(
		"character_creation_profile_respects_none_shirt_pants",
		func() -> void:
			var equip := await _build_profile_equipment(runner, &"", &"")
			runner._assert_true(equip != null, "Profile equipment should not be null")
			if equip == null:
				return

			runner._assert_eq(
				equip.get_equipped_item_id(EquipmentSlots.SHIRT),
				&"",
				"Shirt should start unequipped when selected variant is none"
			)
			runner._assert_eq(
				equip.get_equipped_item_id(EquipmentSlots.PANTS),
				&"",
				"Pants should start unequipped when selected variant is none"
			)
			runner._assert_eq(
				equip.get_equipped_item_id(EquipmentSlots.SHOES),
				&"shoes_brown",
				"Shoes should start equipped (default shoes)"
			)

			await _assert_player_renders_equipment(runner, equip, &"", &"", &"brown")
	)

	runner.add_test(
		"character_creation_profile_equips_selected_shirt_pants",
		func() -> void:
			var equip := await _build_profile_equipment(runner, &"red_blue", &"jeans")
			runner._assert_true(equip != null, "Profile equipment should not be null")
			if equip == null:
				return

			runner._assert_eq(
				equip.get_equipped_item_id(EquipmentSlots.SHIRT),
				&"shirt_red_blue",
				"Shirt should be equipped when selected in character creation"
			)
			runner._assert_eq(
				equip.get_equipped_item_id(EquipmentSlots.PANTS),
				&"jeans",
				"Pants should be equipped when selected in character creation"
			)
			runner._assert_eq(
				equip.get_equipped_item_id(EquipmentSlots.SHOES),
				&"shoes_brown",
				"Shoes should start equipped (default shoes)"
			)

			await _assert_player_renders_equipment(runner, equip, &"red_blue", &"jeans", &"brown")
	)


func _build_profile_equipment(
	runner: Node, shirt_variant: StringName, pants_variant: StringName
) -> PlayerEquipment:
	runner._assert_true(ResourceLoader.exists(_SCREEN_SCRIPT), "Missing character creation script")
	if not ResourceLoader.exists(_SCREEN_SCRIPT):
		return null

	var script: Script = load(_SCREEN_SCRIPT) as Script
	runner._assert_true(script != null, "Character creation script failed to load")
	if script == null:
		return null

	var screen: Control = script.new() as Control
	runner._assert_true(screen != null, "Failed to instantiate character creation screen script")
	if screen == null:
		return null

	var a: CharacterAppearance = CharacterAppearance.new()
	a.shirt_variant = shirt_variant
	a.pants_variant = pants_variant
	screen.set("_appearance", a)

	var profile_any: Variant = screen.call("_build_profile", false)
	runner._assert_true(profile_any is Dictionary, "Profile should be a Dictionary")
	if not (profile_any is Dictionary):
		return null
	var profile: Dictionary = profile_any as Dictionary

	# Ensure the appearance is duplicated (not the same instance we set).
	if profile.has("appearance") and profile["appearance"] is CharacterAppearance:
		runner._assert_true(
			profile["appearance"] != a, "Profile should duplicate CharacterAppearance"
		)

	var equip: PlayerEquipment = null
	if profile.has("equipment") and profile["equipment"] is PlayerEquipment:
		equip = profile["equipment"] as PlayerEquipment
	return equip


func _assert_player_renders_equipment(
	runner: Node,
	equip: PlayerEquipment,
	expected_shirt_variant: StringName,
	expected_pants_variant: StringName,
	expected_shoes_variant: StringName
) -> void:
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

	runner.get_tree().root.add_child(p)
	await runner.get_tree().process_frame

	# Apply equipment and force equipment-driven appearance update.
	p.set("equipment", equip)
	if p.has_method("_apply_equipment_to_appearance"):
		p.call("_apply_equipment_to_appearance")

	var cv_any: Variant = p.get("character_visual")
	var cv: Node = cv_any as Node
	runner._assert_true(cv != null, "Player.character_visual missing")
	if cv == null:
		p.queue_free()
		await runner.get_tree().process_frame
		return

	var app_any: Variant = cv.get("appearance")
	var ca: CharacterAppearance = app_any as CharacterAppearance
	runner._assert_true(ca != null, "Player appearance missing/invalid")
	if ca != null:
		runner._assert_eq(
			ca.shirt_variant,
			expected_shirt_variant,
			"Player rendered shirt variant should match equipped shirt"
		)
		runner._assert_eq(
			ca.pants_variant,
			expected_pants_variant,
			"Player rendered pants variant should match equipped pants"
		)
		runner._assert_eq(
			ca.shoes_variant,
			expected_shoes_variant,
			"Player rendered shoes variant should match equipped shoes"
		)

	p.queue_free()
	await runner.get_tree().process_frame
