class_name QuestReward
extends Resource

## QuestReward
## Rewards are granted by QuestManager when a step/quest completes.


func describe() -> String:
	return "Reward"


func grant(_player: Node) -> void:
	# Concrete rewards override.
	pass
