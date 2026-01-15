extends Control

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var buttons_box: VBoxContainer = %Buttons
@onready var footer_label: Label = %Footer

@onready var continue_button: Button = %ContinueButton
@onready var load_game_button: Button = %LoadGameButton
@onready var settings_button: Button = %SettingsButton


func _ready() -> void:
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	visibility_changed.connect(_on_visibility_changed)

	_refresh_footer()
	_refresh_buttons()
	_play_intro()


func _on_visibility_changed() -> void:
	_refresh_buttons()
	if is_visible_in_tree():
		_play_intro()


func _refresh_footer() -> void:
	if footer_label == null:
		return
	var v: String = str(ProjectSettings.get_setting("application/config/version", "dev"))
	if v.strip_edges().is_empty():
		v = "dev"
	footer_label.text = "v%s" % v


func _refresh_buttons() -> void:
	# UIManager keeps this screen instance alive across state changes, so _ready()
	# won't re-run when returning to menu.
	if not is_visible_in_tree():
		return
	if Runtime == null or Runtime.save_manager == null:
		continue_button.disabled = true
		load_game_button.disabled = true
		return

	# Continue is enabled if there's an active session
	continue_button.disabled = (Runtime.save_manager.load_session_game_save() == null)
	# Load Game is enabled if there are any slots
	var slots = Runtime.save_manager.list_slots()
	var has_session := Runtime.save_manager.load_session_game_save() != null
	load_game_button.disabled = slots.is_empty() and not has_session


func _on_new_game_pressed() -> void:
	if Runtime and Runtime.game_flow:
		await Runtime.game_flow.start_new_game()


func _on_continue_pressed() -> void:
	if Runtime and Runtime.game_flow:
		await Runtime.game_flow.continue_session()


func _on_load_game_pressed() -> void:
	if UIManager != null:
		if UIManager.has_method("show"):
			var node := UIManager.show(UIManager.ScreenName.LOAD_GAME_MENU)
			if node is LoadGameMenu:
				(node as LoadGameMenu).set_mode(
					LoadGameMenu.MenuMode.LOAD, UIManager.ScreenName.MAIN_MENU
				)
			elif node != null and node.has_method("set_mode"):
				node.call("set_mode", LoadGameMenu.MenuMode.LOAD, UIManager.ScreenName.MAIN_MENU)
			return
		if UIManager.has_method("show_load_game_menu"):
			UIManager.show_load_game_menu()
			return


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	if UIManager != null:
		UIManager.show(UIManager.ScreenName.SETTINGS_MENU)


func _play_intro() -> void:
	if not is_visible_in_tree():
		return
	if panel == null:
		return

	# Defer so PanelContainer has a valid size (for pivot centering).
	await get_tree().process_frame
	if not is_visible_in_tree():
		return

	panel.pivot_offset = panel.size * 0.5
	panel.modulate = Color(1, 1, 1, 0.0)
	panel.scale = Vector2(0.92, 0.92)

	var btns: Array[Node] = []
	if buttons_box != null:
		btns = buttons_box.get_children()
	for n in btns:
		if n is CanvasItem:
			(n as CanvasItem).modulate.a = 0.0

	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18)

	var delay := 0.05
	for n in btns:
		if n is CanvasItem:
			t.tween_interval(delay)
			t.tween_property(n, "modulate:a", 1.0, 0.08)
			delay = 0.0
