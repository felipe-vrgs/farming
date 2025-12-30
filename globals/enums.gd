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
	NPC_HOUSE = 2
}

## Global spawn identifiers used by SpawnManager/TravelZone.
## Convention: ENTRY_FROM_<SOURCE>_<ROUTE> to avoid ambiguity when multiple connections exist.
enum SpawnId {
	NONE = 0,
	PLAYER_DEFAULT = 1,
	ENTRY_FROM_ISLAND = 2,
	ENTRY_FROM_NPC_HOUSE = 3,
}

enum AgentKind {
	NONE = 0,
	PLAYER = 1,
	NPC = 2,
}
