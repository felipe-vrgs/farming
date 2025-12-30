class_name NPC
extends CharacterBody2D

## Minimal runtime NPC agent used by AgentSpawner.
## This node is intentionally NOT save-captured via LevelSave (no SaveComponent / persistent group).
## Its state is persisted via AgentRegistry -> AgentsSave.

@export var inventory: InventoryData = null
var money: int = 0

var _components: Node
var _agent_component: AgentComponent

func _init() -> void:
	# Create components up-front so group membership exists as soon as the NPC enters the tree.
	_components = Node.new()
	_components.name = "Components"
	add_child(_components)

	_agent_component = AgentComponent.new()
	_agent_component.name = "AgentComponent"
	_agent_component.kind = Enums.AgentKind.NPC
	_components.add_child(_agent_component)

func _ready() -> void:
	# Avoid mutating shared `.tres` resources from `res://`.
	if inventory != null and String(inventory.resource_path).begins_with("res://"):
		inventory = inventory.duplicate(true)

	# Optional: give the NPC a visible placeholder sprite if none exists.
	if get_node_or_null(NodePath("Sprite2D")) == null:
		var s := Sprite2D.new()
		s.name = "Sprite2D"
		s.texture = preload("res://assets/characters/player/farm_character_walk_frame16x20.png")
		s.centered = true
		add_child(s)

func apply_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	money = int(rec.money)

func capture_agent_record(rec: AgentRecord) -> void:
	if rec == null:
		return
	rec.money = int(money)


