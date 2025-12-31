class_name RouteIds
extends Object

## Centralized route identifiers.
## Keep these stable because NPC configs/schedules reference them.

enum Id {
	NONE = 0,
	ISLAND_LOOP = 1,
	ISLAND_EXIT = 2,
	# Leave 20 gap for each level's routes
	FRIEREN_HOUSE_LOOP = 20,
	FRIEREN_HOUSE_EXIT = 21,
}

const NONE := &""
const ISLAND_LOOP := &"island_loop"
const ISLAND_EXIT := &"island_exit"
const FRIEREN_HOUSE_LOOP := &"frieren_house_loop"
const FRIEREN_HOUSE_EXIT := &"frieren_house_exit"

static func name(id: Id) -> StringName:
	match id:
		Id.NONE:
			return NONE
		Id.ISLAND_LOOP:
			return ISLAND_LOOP
		Id.ISLAND_EXIT:
			return ISLAND_EXIT
		Id.FRIEREN_HOUSE_LOOP:
			return FRIEREN_HOUSE_LOOP
		Id.FRIEREN_HOUSE_EXIT:
			return FRIEREN_HOUSE_EXIT
		_:
			return NONE

