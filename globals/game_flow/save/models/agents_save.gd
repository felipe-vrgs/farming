class_name AgentsSave
extends Resource

## Increment when schema changes.
@export var version: int = 1

## Persisted agent records (player + NPCs).
@export var agents: Array[AgentRecord] = []


