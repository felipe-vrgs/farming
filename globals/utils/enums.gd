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

enum AgentKind {
	NONE = 0,
	PLAYER = 1,
	NPC = 2,
}

## Runtime "world mode" state (orthogonal to GameFlow menu/pause).
## - RUNNING: normal gameplay
## - DIALOGUE: full pause (SceneTree paused); only dialogue UI should process
## - CUTSCENE: SceneTree running; controllers/AI disabled; cutscene scripts drive motion
enum FlowState {
	RUNNING = 0,
	DIALOGUE = 1,
	CUTSCENE = 2,
}
