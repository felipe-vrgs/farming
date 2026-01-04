class_name InteractionContext
extends Object

## InteractionContext is a small payload passed to InteractableComponents.
## Keep it flexible so "tool use" and "use/action" can share the same API.

enum Kind {
	TOOL = 0,
	USE = 1,
}

var kind: Kind = Kind.TOOL

## Who initiated the interaction (usually Player, later NPCs, etc.)
var actor: Node = null

## Tool being used (only relevant for Kind.TOOL).
var tool_data: ToolData = null

## Targeted grid cell (used by grid-based interactions).
var cell: Vector2i = Vector2i.ZERO

## Optional: direct hit/target info (useful for raycast-based "use").
var target: Node = null
var hit_world_pos: Vector2 = Vector2.ZERO


func is_tool(action_kind: Enums.ToolActionKind = Enums.ToolActionKind.NONE) -> bool:
	if tool_data == null:
		return false
	if kind != Kind.TOOL:
		return false
	if action_kind == Enums.ToolActionKind.NONE:
		return true
	if tool_data.action_kind != action_kind:
		return false
	return true


func is_use() -> bool:
	return kind == Kind.USE
