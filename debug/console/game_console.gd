extends CanvasLayer

var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = -1
var _modules: Array[RefCounted] = []

@onready var log_display: RichTextLabel = %LogDisplay
@onready var input_field: LineEdit = %InputField
@onready var container: Control = %ConsoleContainer

func _ready() -> void:
	if not OS.is_debug_build():
		set_process_input(false)
		queue_free()
		return

	container.visible = false
	# Adjust console size and font programmatically
	var panel = container.get_node("Panel")
	if panel:
		# Use anchors to take up 40% of the screen height
		panel.anchors_preset = Control.PRESET_TOP_WIDE
		panel.anchor_bottom = 1
		panel.offset_bottom = 0
		panel.custom_minimum_size.y = 0

	# Ensure font size is small but readable for 320x180 base resolution
	var font_size = 8
	log_display.add_theme_font_size_override("normal_font_size", font_size)
	log_display.add_theme_font_size_override("bold_font_size", font_size)
	log_display.add_theme_font_size_override("italics_font_size", font_size)
	log_display.add_theme_font_size_override("mono_font_size", font_size)
	input_field.add_theme_font_size_override("font_size", font_size)

	register_command("help", _cmd_help, "Shows this help message", "General")
	_load_module(CommandsGeneral.new())
	_load_module(CommandsSave.new())
	_load_module(CommandsNPC.new())

	# Manually handle input to avoid focus loss issues
	# We removed the signal in the scene, so we just connect GUI input here
	input_field.gui_input.connect(_on_input_field_gui_input)
	print_line("Welcome to the Farming Game Debug Console. Type 'help' for commands.")

func _load_module(mod: RefCounted) -> void:
	if mod.has_method("register"):
		mod.register(self)
		_modules.append(mod)

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

func register_command(cmd: String,
	callable: Callable,
	description: String = "",
	category: String = "General"
) -> void:
	_commands[cmd] = {
		"func": callable,
		"desc": description,
		"category": category
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

	var by_cat: Dictionary = {}
	for cmd in _commands:
		var cat = _commands[cmd].get("category", "General")
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(cmd)

	var categories = by_cat.keys()
	categories.sort()

	for cat in categories:
		print_line("[%s]" % cat, "cyan")
		var cmds = by_cat[cat]
		cmds.sort()
		for cmd in cmds:
			print_line("  " + cmd + ": " + _commands[cmd]["desc"])
