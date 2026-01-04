extends Node

## Bootstraps the headless test runner as a child of SceneTree.root so it survives
## scene changes (Runtime/GameFlow smoke tests swap scenes).

const RUNNER_SCRIPT := "res://tests/headless/run_tests.gd"


func _ready() -> void:
	# Ensure we only spawn one runner if this scene is somehow reloaded.
	var root := get_tree().root
	if root == null:
		return
	if root.get_node_or_null(NodePath("HeadlessTestRunner")) != null:
		return

	var script = load(RUNNER_SCRIPT)
	if script == null or not (script is Script):
		push_error("Headless tests: failed to load runner script: " + RUNNER_SCRIPT)
		get_tree().quit(2)
		return

	var runner = (script as Script).new()
	if runner == null or not (runner is Node):
		push_error("Headless tests: runner script did not instantiate a Node")
		get_tree().quit(2)
		return

	(runner as Node).name = "HeadlessTestRunner"
	# Avoid "Parent node is busy setting up children" during initial scene boot.
	root.add_child.call_deferred(runner)
