class_name QuestRewardMoney
extends QuestReward

@export var amount: int = 0


func describe() -> String:
	return "Money: %d" % int(amount)


func grant(player: Node) -> void:
	if player == null or not ("money" in player):
		return
	player.money = int(player.money) + int(amount)
