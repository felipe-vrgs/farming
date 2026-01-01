@tool
extends Node

enum EntityType {
	GENERIC = 0,
	PLANT = 1,
	TREE = 2,
	ROCK = 3,
	BUILDING = 4,
	PLAYER = 5,
	NPC = 6,
}

enum ToolActionKind {
	NONE = 0,
	HOE = 1,
	WATER = 2,
	SHOVEL = 3,
	AXE = 4,
	HARVEST = 5
}

enum ToolSwishType {
	NONE = 0,
	SLASH = 1,
	SWIPE = 2,
	STRIKE = 3
}

enum Levels {
	NONE = 0,
	ISLAND = 1,
	FRIEREN_HOUSE = 2
}

enum SpawnId {
	NONE = 0,
	PLAYER_SPAWN = 1,
	ENTRY_FROM_ISLAND = 2,
	ENTRY_FROM_FRIEREN_HOUSE = 3,
	FRIEREN_SPAWN = 4,
}

enum AgentKind {
	NONE = 0,
	PLAYER = 1,
	NPC = 2,
}

enum PlayerPlacementPolicy {
	RECORD_OR_SPAWN = 0,
	SPAWN_MARKER = 1,
	RECORD = 2,
}