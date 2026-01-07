class_name HealthComponent
extends Node2D

## Signal emitted when health changes.
signal health_changed(current: float, max: float)
## Signal emitted when health reaches zero.
signal depleted

@export var max_health: float = 100.0

@export_group("Composition: Hit Flash")
## When enabled, HealthComponent will configure/drive a HitFlashComponent on the entity.
@export var enable_hit_flash: bool = false
## Sprite/CanvasItem to flash on damage (usually Sprite2D/AnimatedSprite2D).
@export var hit_flash_nodes: Array[CanvasItem] = []
@export var hit_flash_color: Color = Color(1, 1, 1, 1)
@export var hit_flash_duration: float = 0.1

@export_group("Composition: Shake")
## When enabled, HealthComponent will configure/drive a ShakeComponent on the entity.
@export var enable_shake: bool = false
## Node to shake (usually Camera2D).
@export var shake_nodes: Array[Node2D] = []
@export var shake_strength: float = 2.0
@export var shake_duration: float = 0.2
@export var shake_decay: bool = true

@export_group("Composition: Damage On Interact")
## When enabled, HealthComponent will configure/attach a DamageOnInteract
## InteractableComponent on the entity.
@export var enable_damage_on_interact: bool = false
@export var damage_on_interact_priority: int = 0
@export var damage_on_interact_required_action: Enums.ToolActionKind = Enums.ToolActionKind.NONE
@export var damage_on_interact_damage: float = 25.0
@export var damage_on_interact_hit_sound: AudioStream = null

@export_group("Composition: Drop Loot")
## When enabled, HealthComponent will configure/attach a LootComponent on the entity.
@export var enable_loot: bool = false
@export var loot_item: ItemData = null
@export var loot_count: int = 1
@export var loot_spawn_count: int = 1

var _hit_flash: HitFlashComponent = null
var _damage_on_interact: DamageOnInteract = null
var _shake: ShakeComponent = null
var _loot: LootComponent = null

@onready var current_health: float = max_health


func _ready() -> void:
	var entity := _get_entity()
	if entity == null:
		return

	var container := _get_components_container(entity)
	if container == null:
		return

	_setup_hit_flash_composition(container)
	_setup_damage_on_interact_composition(container)
	_setup_shake_composition(container)
	_setup_loot_composition(entity)


## Apply damage to this component.
func take_damage(amount: float) -> void:
	if current_health <= 0:
		return
	if amount <= 0:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if enable_hit_flash and _hit_flash != null and is_instance_valid(_hit_flash):
		_hit_flash.on_flash_requested()

	if enable_shake and _shake != null and is_instance_valid(_shake):
		_shake.on_shake_requested()

	if current_health <= 0:
		depleted.emit()
		if enable_loot and _loot != null and is_instance_valid(_loot):
			_loot.spawn_loot()


## Reset health to max.
func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func get_save_state() -> Dictionary:
	return {"current_health": current_health}


func apply_save_state(state: Dictionary) -> void:
	if state.has("current_health"):
		current_health = float(state["current_health"])
		# Clamp just in case config changed
		current_health = clampf(current_health, 0.0, max_health)
		# Notify listeners (like UI bars) that value loaded
		health_changed.emit(current_health, max_health)


func _get_entity() -> Node:
	# Mirror InteractableComponent.get_entity() convention so composition works
	# regardless of whether this component is placed directly under the entity
	# or under an entity's `Components/` container.
	var p := get_parent()
	if p == null:
		return null
	if StringName(p.name) == &"Components":
		return p.get_parent()
	return p


func _get_components_container(entity: Node) -> Node:
	if entity == null:
		return null
	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		return components as Node
	return entity


func _setup_hit_flash_composition(container: Node) -> void:
	if not enable_hit_flash:
		return

	_hit_flash = HitFlashComponent.new()
	_hit_flash.name = &"HitFlash"
	container.add_child.call_deferred(_hit_flash)
	_hit_flash.flash_color = hit_flash_color
	_hit_flash.flash_duration = hit_flash_duration
	if not hit_flash_nodes.is_empty():
		_hit_flash.flash_nodes = hit_flash_nodes.duplicate()


func _setup_damage_on_interact_composition(container: Node) -> void:
	if not enable_damage_on_interact:
		return

	_damage_on_interact = DamageOnInteract.new()
	_damage_on_interact.name = &"DamageOnInteract"
	container.add_child.call_deferred(_damage_on_interact)
	_damage_on_interact.priority = damage_on_interact_priority
	_damage_on_interact.required_action_kind = damage_on_interact_required_action
	_damage_on_interact.damage = damage_on_interact_damage
	var sound := damage_on_interact_hit_sound
	if sound == null:
		sound = preload("res://assets/sounds/tools/chop.ogg")
	_damage_on_interact.hit_sound = sound
	_damage_on_interact.health_component = self


func _setup_shake_composition(container: Node) -> void:
	if not enable_shake:
		return

	_shake = ShakeComponent.new()
	_shake.name = &"Shake"
	container.add_child.call_deferred(_shake)
	if not shake_nodes.is_empty():
		_shake.target_nodes = shake_nodes.duplicate()
	_shake.shake_strength = shake_strength
	_shake.shake_duration = shake_duration
	_shake.shake_decay = shake_decay


func _setup_loot_composition(entity: Node) -> void:
	if not enable_loot:
		return

	_loot = LootComponent.new()
	_loot.name = &"Loot"
	# Important: LootComponent.spawn_loot() frees its parent, so this must be the entity root
	# (not the Components/ container), otherwise we would only delete Components/.
	entity.add_child.call_deferred(_loot)
	_loot.loot_item = loot_item
	_loot.loot_count = loot_count
	_loot.spawn_count = loot_spawn_count
