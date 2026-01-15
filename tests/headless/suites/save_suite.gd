extends RefCounted


func register(runner: Node) -> void:
	var sm = load("res://game/globals/game_flow/save/save_manager.gd").new()
	# Avoid contaminating real user saves: use a unique session id.
	var session_id := "test_session_%d" % int(Time.get_ticks_msec())
	runner.add_test(
		"save_manager_roundtrip",
		func() -> void:
			sm.call("set_session", session_id)
			sm.call("reset_session")

			var gs := GameSave.new()
			gs.active_level_id = Enums.Levels.ISLAND
			gs.current_day = 7
			gs.minute_of_day = 123

			runner._assert_true(
				sm.save_session_game_save(gs), "SaveManager should save session game.tres"
			)

			var gs2 = sm.load_session_game_save()
			runner._assert_true(gs2 != null, "SaveManager should load session game.tres")
			runner._assert_eq(int(gs2.current_day), 7, "GameSave roundtrip current_day")
			runner._assert_eq(int(gs2.minute_of_day), 123, "GameSave roundtrip minute_of_day")
			runner._assert_eq(
				int(gs2.active_level_id),
				int(Enums.Levels.ISLAND),
				"GameSave roundtrip active_level_id"
			)

			# Slot copy smoke.
			runner._assert_true(
				sm.copy_session_to_slot("test_slot"), "copy_session_to_slot should succeed"
			)
			runner._assert_true(
				sm.slot_exists("test_slot"), "slot_exists should be true after copy"
			)

			# Cleanup best-effort.
			sm.delete_slot("test_slot")
			sm.reset_session()
	)

	runner.add_test(
		"save_manager_level_save_roundtrip",
		func() -> void:
			sm.set_session(session_id)
			sm.reset_session()

			var ls := LevelSave.new()
			ls.level_id = Enums.Levels.FRIEREN_HOUSE
			ls.frieren_house_tier = 2

			var cs := CellSnapshot.new()
			cs.coords = Vector2i(5, 5)
			cs.terrain_id = 2
			ls.cells = [cs]

			runner._assert_true(sm.save_session_level_save(ls), "Should save level save")

			var ls2 = sm.load_session_level_save(Enums.Levels.FRIEREN_HOUSE)
			runner._assert_true(ls2 != null, "Should load level save")
			runner._assert_eq(
				int(ls2.level_id), int(Enums.Levels.FRIEREN_HOUSE), "Level ID should match"
			)
			runner._assert_eq(int(ls2.frieren_house_tier), 2, "Frieren house tier roundtrip")
			runner._assert_eq(ls2.cells.size(), 1, "Cells count should match")
			runner._assert_eq(ls2.cells[0].coords, Vector2i(5, 5), "Cell coords should match")

			var ids = sm.list_session_level_ids()
			runner._assert_true(
				Enums.Levels.FRIEREN_HOUSE in ids, "Level ID should be in session level ids list"
			)

			sm.reset_session()
	)

	runner.add_test(
		"save_manager_agents_save_roundtrip",
		func() -> void:
			sm.set_session(session_id)
			sm.reset_session()

			var asave := AgentsSave.new()
			var rec := AgentRecord.new()
			rec.agent_id = &"test_agent"
			asave.agents = [rec]

			runner._assert_true(sm.save_session_agents_save(asave), "Should save agents save")

			var asave2 = sm.load_session_agents_save()
			runner._assert_true(asave2 != null, "Should load agents save")
			runner._assert_eq(asave2.agents.size(), 1, "Agents count should match")
			runner._assert_eq(
				String(asave2.agents[0].agent_id), "test_agent", "Agent ID should match"
			)

			sm.reset_session()
	)

	runner.add_test(
		"save_manager_agents_save_roundtrip_includes_customization",
		func() -> void:
			sm.set_session(session_id)
			sm.reset_session()

			var asave := AgentsSave.new()
			var rec := AgentRecord.new()
			rec.agent_id = &"player"
			rec.display_name = "Alice"
			var a := CharacterAppearance.new()
			a.skin_color = Color(0.2, 0.3, 0.4, 1.0)
			a.eye_color = Color(0.7, 0.1, 0.2, 1.0)
			a.face_variant = &"female"
			rec.appearance = a

			var equip := PlayerEquipment.new()
			equip.set_equipped_item_id(EquipmentSlots.SHIRT, &"shirt_red_blue")
			equip.set_equipped_item_id(EquipmentSlots.PANTS, &"pants_jeans")
			rec.equipment = equip

			asave.agents = [rec]
			runner._assert_true(sm.save_session_agents_save(asave), "Should save agents save")

			var asave2: AgentsSave = sm.load_session_agents_save()
			runner._assert_true(asave2 != null, "Should load agents save")
			var rec2: AgentRecord = asave2.agents[0]
			runner._assert_eq(String(rec2.display_name), "Alice", "display_name roundtrip")
			runner._assert_true(rec2.appearance != null, "appearance should roundtrip")
			if rec2.appearance != null:
				runner._assert_eq(
					rec2.appearance.skin_color, Color(0.2, 0.3, 0.4, 1.0), "skin_color roundtrip"
				)
				runner._assert_eq(
					rec2.appearance.eye_color, Color(0.7, 0.1, 0.2, 1.0), "eye_color roundtrip"
				)
				runner._assert_eq(
					StringName(rec2.appearance.face_variant), &"female", "face_variant roundtrip"
				)
			runner._assert_true(rec2.equipment != null, "equipment should roundtrip")
			if rec2.equipment != null:
				var e := rec2.equipment as PlayerEquipment
				runner._assert_true(e != null, "equipment should deserialize as PlayerEquipment")
				if e == null:
					sm.reset_session()
					return
				runner._assert_eq(
					StringName(e.get_equipped_item_id(EquipmentSlots.SHIRT)),
					&"shirt_red_blue",
					"equipped shirt roundtrip"
				)
				runner._assert_eq(
					StringName(e.get_equipped_item_id(EquipmentSlots.PANTS)),
					&"pants_jeans",
					"equipped pants roundtrip"
				)

			sm.reset_session()
	)

	runner.add_test(
		"agent_component_capture_pre_ready_does_not_overwrite_inventory_or_equipment",
		func() -> void:
			# Regression: during loading, apply_record can defer while capture runs immediately.
			# Capturing before the agent is node-ready must not wipe persisted inventory/equipment.
			var p := Player.new()

			# Attach an AgentComponent so we can exercise its apply/capture logic.
			var ac := AgentComponent.new()
			ac.kind = Enums.AgentKind.PLAYER
			ac.agent_id = &"player"
			p.add_child(ac)

			var inv := InventoryData.new()
			inv.slots = [InventorySlot.new()]
			var it := ItemData.new()
			it.id = &"test_item"
			it.stackable = false
			it.max_stack = 1
			inv.slots[0].item_data = it
			inv.slots[0].count = 1

			var equip := PlayerEquipment.new()
			equip.set_equipped_item_id(EquipmentSlots.SHIRT, &"shirt_red_blue")

			var rec := AgentRecord.new()
			rec.agent_id = &"player"
			rec.kind = Enums.AgentKind.PLAYER
			rec.display_name = "Alice"
			rec.inventory = inv
			rec.equipment = equip

			# Pre-ready apply should not rely on onready fields.
			ac.apply_record(rec, false)
			# Simulate the problematic sequence: capture immediately after apply while not ready.
			ac.capture_into_record(rec)

			runner._assert_true(rec.inventory != null, "inventory should not be cleared pre-ready")
			runner._assert_true(rec.equipment != null, "equipment should not be cleared pre-ready")
			var e := rec.equipment as PlayerEquipment
			runner._assert_true(e != null, "equipment should remain a PlayerEquipment resource")
			if e != null:
				runner._assert_eq(
					StringName(e.get_equipped_item_id(EquipmentSlots.SHIRT)),
					&"shirt_red_blue",
					"equipped shirt should survive pre-ready capture"
				)

			p.free()
	)

	runner.add_test(
		"player_equip_swap_returns_old_item_to_inventory",
		func() -> void:
			var p := Player.new()

			var inv := InventoryData.new()
			# 3 slots: one with the new shirt, two empty for swap-back.
			inv.slots = [InventorySlot.new(), null, null]
			var shirt_item: ItemData = (
				load("res://game/entities/items/resources/shirt_red_blue.tres") as ItemData
			)
			inv.slots[0].item_data = shirt_item
			inv.slots[0].count = 1
			p.inventory = inv

			# Inject a resolvable "old shirt" into ItemResolver cache so swap-back works in tests.
			var clothing_script := load("res://game/entities/items/models/clothing_item_data.gd")
			var old_shirt: ItemData = clothing_script.new()
			old_shirt.id = &"shirt_alt"
			old_shirt.display_name = "Alt Shirt"
			old_shirt.stackable = false
			old_shirt.max_stack = 1
			old_shirt.set("slot", &"shirt")
			old_shirt.set("variant", &"red_blue")
			ItemResolver._cache[old_shirt.id] = old_shirt

			p.set_equipped_item_id(&"shirt", &"shirt_alt")
			var ok := p.try_equip_clothing_from_inventory(0, &"shirt")
			runner._assert_true(ok, "Equip should succeed")
			runner._assert_eq(
				p.get_equipped_item_id(&"shirt"),
				&"shirt_red_blue",
				"Equipped shirt should be new item"
			)

			# Old shirt should now be in inventory.
			var found_old := false
			for s in p.inventory.slots:
				if s != null and s.item_data != null and s.item_data.id == &"shirt_alt":
					found_old = true
			runner._assert_true(found_old, "Old equipped shirt should be returned to inventory")
			ItemResolver._cache.erase(&"shirt_alt")
			p.free()
	)

	runner.add_test(
		"inventory_stacks_by_item_id_not_resource_identity",
		func() -> void:
			var inv := InventoryData.new()
			inv.slots = [InventorySlot.new()]

			var a := ItemData.new()
			a.id = &"test_stack"
			a.stackable = true
			a.max_stack = 99

			var b := ItemData.new()
			# Different instance, same id.
			b.id = &"test_stack"
			b.stackable = true
			b.max_stack = 99

			inv.slots[0].item_data = a
			inv.slots[0].count = 1

			var remaining := inv.add_item(b, 1)
			runner._assert_eq(int(remaining), 0, "add_item should fully stack by id")
			runner._assert_true(inv.slots[0] != null, "slot should exist")
			runner._assert_eq(int(inv.slots[0].count), 2, "count should increase when stacking")
	)
