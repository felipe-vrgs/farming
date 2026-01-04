class_name AgentStatus
extends RefCounted

## AgentStatus - feedback from spawned NPC to AgentBrain.
##
## NPCs report their status each physics frame so the brain can:
## - Know when an agent reached their target (advance waypoint)
## - Know when an agent is blocked (and why)
## - Track actual positions for travel commit detection

var agent_id: StringName = &""

## Current world position of the agent.
var position: Vector2 = Vector2.ZERO

## True if the agent reached their order's target_position.
var reached_target: bool = false

## Blocking state.
var is_blocked: bool = false
var block_reason: AgentOrder.BlockReason = AgentOrder.BlockReason.NONE

## How long the agent has been blocked (seconds), for timeout logic.
var blocked_duration: float = 0.0


func _to_string() -> String:
	var blocked_str := ""
	if is_blocked:
		blocked_str = (
			", BLOCKED(%s, %.1fs)" % [AgentOrder.BlockReason.keys()[block_reason], blocked_duration]
		)
	return (
		"AgentStatus(%s, pos=%s, reached=%s%s)" % [agent_id, position, reached_target, blocked_str]
	)
