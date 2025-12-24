extends CanvasLayer

var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = -1

@onready var log_display: RichTextLabel = %LogDisplay
@onready var input_field: LineEdit = %InputField
@onready var container: Control = %ConsoleContainer

func _ready() -> void:
	if not OS.is_debug_build():
		set_process_input(false)
		queue_free()
		return

	container.visible = false
	register_command("help", _cmd_help, "Shows this help message")
	register_command("clear", _cmd_clear, "Clears the console log")
	register_command("quit", _cmd_quit, "Quits the game")
	register_command("give", _cmd_give, "Usage: give <item_id> [amount]")
	register_command("time", _cmd_time, "Usage: time [skip|scale <float>]")
	# Manually handle input to avoid focus loss issues
	# We removed the signal in the scene, so we just connect GUI input here
	input_field.gui_input.connect(_on_input_field_gui_input)
	print_line("Welcome to the Farming Game Debug Console. Type 'help' for commands.")

func _on_input_field_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_input_submitted(input_field.text)
		input_field.accept_event() # Prevent default behavior (which might be losing focus)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_APOSTROPHE:
			toggle_console()
			get_viewport().set_input_as_handled()
		elif container.visible:
			if event.keycode == KEY_UP:
				_navigate_history(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_navigate_history(-1)
				get_viewport().set_input_as_handled()

func toggle_console() -> void:
	container.visible = not container.visible
	if container.visible:
		input_field.grab_focus()
		get_tree().paused = true
	else:
		input_field.release_focus()
		get_tree().paused = false

func register_command(cmd: String, callable: Callable, description: String = "") -> void:
	_commands[cmd] = {
		"func": callable,
		"desc": description
	}

func print_line(text: String, color: String = "white") -> void:
	log_display.push_color(Color(color))
	log_display.add_text(text + "\n")
	log_display.pop()

func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		_refocus_input()
		return

	input_field.clear()
	print_line("> " + text, "gray")
	_history.append(text)
	_history_index = -1
	var parts = text.split(" ", false)
	var cmd_name = parts[0]
	var args = parts.slice(1)

	if _commands.has(cmd_name):
		var cmd = _commands[cmd_name]
		cmd["func"].call(args)
	else:
		print_line("Unknown command: " + cmd_name, "red")
	_refocus_input()

func _refocus_input() -> void:
	input_field.call_deferred("grab_focus")

func _navigate_history(off: int) -> void:
	if _history.is_empty():
		return

	if _history_index == -1:
		_history_index = _history.size()

	_history_index = clamp(_history_index - off, 0, _history.size())

	if _history_index == _history.size():
		input_field.text = ""
	else:
		input_field.text = _history[_history_index]
		input_field.caret_column = input_field.text.length()

# --- Built-in Commands ---

func _cmd_help(_args: Array) -> void:
	print_line("--- Available Commands ---", "yellow")
	for cmd in _commands:
		print_line(cmd + ": " + _commands[cmd]["desc"])

func _cmd_clear(_args: Array) -> void:
	log_display.clear()

func _cmd_quit(_args: Array) -> void:
	get_tree().quit()

func _cmd_give(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: give <item_id> [amount]", "yellow")
		return

	var item_id = args[0]
	var amount = 1
	if args.size() > 1:
		amount = int(args[1])

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print_line("Error: Player not found. Is the scene loaded?", "red")
		return

	# Try to find the resource by name in standard paths
	var valid_paths = [
		"res://entities/items/resources/item_%s.tres" % item_id,
		"res://entities/items/resources/%s.tres" % item_id,
		"res://entities/items/%s.tres" % item_id
	]

	var item_data: ItemData = null
	for path in valid_paths:
		if ResourceLoader.exists(path):
			item_data = load(path) as ItemData
			if item_data:
				break

	if not item_data:
		print_line("Error: Could not find item resource for '%s'" % item_id, "red")
		return

	var leftover = player.inventory.add_item(item_data, amount)
	if leftover == 0:
		print_line(str("Gave %d x %s" % [amount, item_data.display_name]), "green")
	else:
		print_line(
            str("Gave %d x %s (Inventory full!)") % [amount - leftover, item_data.display_name],
            "yellow"
        )

func _cmd_time(args: Array) -> void:
	if args.is_empty():
		var day = str(TimeManager.current_day) if TimeManager else "?"
		print_line(str("Current Day: %s") % day)
		return

	var sub = args[0]
	if sub == "skip":
		if TimeManager:
			TimeManager.advance_day()
			print_line("Skipped to Day %d" % TimeManager.current_day, "green")
	elif sub == "scale":
		if args.size() > 1:
			var s = float(args[1])
			Engine.time_scale = s
			print_line("Time scale: %.2f" % s)
		else:
			print_line("Current time scale: %.2f" % Engine.time_scale)
