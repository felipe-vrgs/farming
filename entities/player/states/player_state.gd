class_name PlayerState
extends State

var player: Player
var player_balance_config: PlayerBalanceConfig


func bind_parent(new_parent: Node) -> void:
	super.bind_parent(new_parent)
	if new_parent is Player:
		player = new_parent
		player_balance_config = player.player_balance_config


func enter() -> void:
	super.enter()
	# Refresh config in case it changed (unlikely but good practice)
	if player:
		player_balance_config = player.player_balance_config
