class_name ConsoleCommandModule
extends RefCounted

var _console: Node

func register(console: Node) -> void:
	_console = console
	_register_commands()

func get_category() -> String:
	return "General"

func _register_commands() -> void:
	pass

func _cmd(name: String, callback: Callable, desc: String = "") -> void:
	if _console:
		_console.register_command(name, callback, desc, get_category())

func _print(text: String, color: String = "white") -> void:
	if _console:
		_console.print_line(text, color)
