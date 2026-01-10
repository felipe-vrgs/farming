class_name PlayerMenu
extends Control

enum Tab { INVENTORY = 0, QUESTS = 1, RELATIONSHIPS = 2 }

@onready var tabs: TabContainer = %Tabs
@onready var inventory_panel: Node = %InventoryPanel
@onready var quest_panel: Node = %QuestPanel
@onready var relationships_panel: Node = %RelationshipsPanel
@onready var money_label: Label = %MoneyLabel
@onready var portrait_sprite: AnimatedSprite2D = %PortraitSprite
@onready var name_label: Label = %NameLabel
@onready var energy_label: Label = %EnergyLabel

var player: Player = null
var _last_tab_index: int = 0
var _energy_component: EnergyComponent = null
var _last_money: int = -2147483648
var _money_poll_accum_s: float = 0.0


func _ready() -> void:
	# Allow this UI to function while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we capture input above gameplay.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Capture Tab/etc before the UI system uses it for focus navigation.
	set_process_input(true)
	set_process(true)
	if tabs != null:
		tabs.tab_changed.connect(_on_tab_changed)


func _input(event: InputEvent) -> void:
	if event == null or not is_visible_in_tree():
		return

	# Close the player menu with Tab.
	# We use _input (not _unhandled_input) so TabContainer can't swallow it first.
	if event.is_action_pressed(&"open_player_menu", false, true):
		if Runtime != null and Runtime.game_flow != null:
			Runtime.game_flow.toggle_player_menu()
			get_viewport().set_input_as_handled()
		return

	# While open: allow switching tabs with direct-open actions.
	if event.is_action_pressed(&"open_player_menu_inventory", false, true):
		if tabs != null and tabs.current_tab == int(Tab.INVENTORY):
			if Runtime != null and Runtime.game_flow != null:
				Runtime.game_flow.toggle_player_menu()
		else:
			open_tab(Tab.INVENTORY)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"open_player_menu_quests", false, true):
		if tabs != null and tabs.current_tab == int(Tab.QUESTS):
			if Runtime != null and Runtime.game_flow != null:
				Runtime.game_flow.toggle_player_menu()
		else:
			open_tab(Tab.QUESTS)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"open_player_menu_relationships", false, true):
		if tabs != null and tabs.current_tab == int(Tab.RELATIONSHIPS):
			if Runtime != null and Runtime.game_flow != null:
				Runtime.game_flow.toggle_player_menu()
		else:
			open_tab(Tab.RELATIONSHIPS)
		get_viewport().set_input_as_handled()
		return


func rebind(new_player: Player = null) -> void:
	# Disconnect previous player signals.
	if _energy_component != null and is_instance_valid(_energy_component):
		var cb := Callable(self, "_on_energy_changed")
		if _energy_component.is_connected("energy_changed", cb):
			_energy_component.disconnect("energy_changed", cb)

	player = new_player
	_last_money = -2147483648
	_refresh_money()
	_refresh_player_summary()
	if inventory_panel != null and inventory_panel.has_method("rebind"):
		inventory_panel.call("rebind", player)
	if quest_panel != null and quest_panel.has_method("rebind"):
		quest_panel.call("rebind")
	if relationships_panel != null and relationships_panel.has_method("rebind"):
		relationships_panel.call("rebind")

	# Keep the energy label live while the menu is open.
	_energy_component = player.energy_component if player != null else null
	if _energy_component != null and is_instance_valid(_energy_component):
		var cb := Callable(self, "_on_energy_changed")
		if not _energy_component.is_connected("energy_changed", cb):
			_energy_component.connect("energy_changed", cb)

	# Do not force a tab here; GameFlow decides via open_tab().


func _refresh_money() -> void:
	if money_label == null:
		return
	var amount := 0
	if player != null and "money" in player:
		amount = int(player.money)
	if amount == _last_money:
		return
	_last_money = amount
	money_label.text = "%d" % amount


func _process(delta: float) -> void:
	# Money can change while the menu is open (quest rewards, shop, etc.).
	# There is no central money_changed signal, so we do a lightweight poll.
	if not is_visible_in_tree():
		_money_poll_accum_s = 0.0
		return
	_money_poll_accum_s += float(delta)
	if _money_poll_accum_s < 0.25:
		return
	_money_poll_accum_s = 0.0
	_refresh_money()


func _refresh_player_summary() -> void:
	if name_label != null:
		# TODO: if you add a proper player name later, use it here.
		name_label.text = "Player"

	# Portrait: play the player's idle animation in a mini AnimatedSprite2D.
	if portrait_sprite != null:
		var src: AnimatedSprite2D = null
		if player != null and is_instance_valid(player) and "animated_sprite" in player:
			src = player.animated_sprite

		if src != null and src.sprite_frames != null:
			portrait_sprite.sprite_frames = src.sprite_frames
			if portrait_sprite.sprite_frames.has_animation(&"idle_front"):
				portrait_sprite.animation = &"idle_front"
			else:
				# Fallback: keep whatever animation exists.
				portrait_sprite.animation = src.animation
			portrait_sprite.play()
			portrait_sprite.visible = true
		else:
			portrait_sprite.stop()
			portrait_sprite.visible = false

	# Energy
	if energy_label != null:
		var cur := -1.0
		var max_v := -1.0
		if player != null and is_instance_valid(player) and player.energy_component != null:
			cur = float(player.energy_component.current_energy)
			max_v = float(player.energy_component.max_energy)
		if cur >= 0.0 and max_v >= 0.0:
			energy_label.text = "Energy: %d/%d" % [int(cur), int(max_v)]
		else:
			energy_label.text = "Energy: -/-"


func _on_energy_changed(_current: float, _max: float) -> void:
	_refresh_player_summary()


func open_tab(tab_index: int) -> void:
	if tabs == null:
		return
	var idx := int(tab_index)
	if idx < 0:
		idx = _last_tab_index
	# Clamp to existing tabs.
	idx = clampi(idx, 0, maxi(0, tabs.get_tab_count() - 1))
	tabs.current_tab = idx
	_last_tab_index = idx


func get_current_tab() -> int:
	if tabs == null:
		return -1
	return int(tabs.current_tab)


func _on_tab_changed(tab: int) -> void:
	_last_tab_index = int(tab)
