class_name Groups
extends Object

## Centralized group identifiers.
enum Id {
	PLAYER,
	PERSISTENT_ENTITIES,
	PERSISTENT_ENTITY_COMPONENTS,
	SAVE_COMPONENTS,
	GRID_OCCUPANT_COMPONENTS,
	INTERACTABLE_COMPONENTS,
	AGENT_COMPONENTS,
	CUTSCENE_ACTOR_COMPONENTS,
	ROUTES,
	NPC,
	MODAL,
}

const PLAYER := &"player"
const PERSISTENT_ENTITIES := &"persistent_entities"
const PERSISTENT_ENTITY_COMPONENTS := &"persistent_entity_components"
const SAVE_COMPONENTS := &"save_components"
const GRID_OCCUPANT_COMPONENTS := &"grid_occupant_components"
const INTERACTABLE_COMPONENTS := &"interactable_components"
const AGENT_COMPONENTS := &"agent_components"
const CUTSCENE_ACTOR_COMPONENTS := &"cutscene_actor_components"
const ROUTES := &"routes"
const NPC_GROUP := &"npc"
const MODAL := &"modal"


static func name(id: Id) -> StringName:
	match id:
		Id.PLAYER:
			return PLAYER
		Id.NPC:
			return NPC_GROUP
		Id.MODAL:
			return MODAL
		Id.PERSISTENT_ENTITIES:
			return PERSISTENT_ENTITIES
		Id.PERSISTENT_ENTITY_COMPONENTS:
			return PERSISTENT_ENTITY_COMPONENTS
		Id.SAVE_COMPONENTS:
			return SAVE_COMPONENTS
		Id.GRID_OCCUPANT_COMPONENTS:
			return GRID_OCCUPANT_COMPONENTS
		Id.INTERACTABLE_COMPONENTS:
			return INTERACTABLE_COMPONENTS
		Id.AGENT_COMPONENTS:
			return AGENT_COMPONENTS
		Id.CUTSCENE_ACTOR_COMPONENTS:
			return CUTSCENE_ACTOR_COMPONENTS
		Id.ROUTES:
			return ROUTES
		_:
			return &""
