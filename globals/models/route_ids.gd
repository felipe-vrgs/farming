class_name RouteIds
extends Object

## Centralized route identifiers.
## Keep these stable because NPC configs/schedules reference them.

enum Id {
	NONE = 0,
	ISLAND_LOOP = 1,
	FRIEREN_HOUSE_LOOP = 2,
}

const NONE := &""
const ISLAND_LOOP := &"island_loop"
const FRIEREN_HOUSE_LOOP := &"frieren_house_loop"

static func name(id: Id) -> StringName:
	match id:
		Id.NONE:
			return NONE
		Id.ISLAND_LOOP:
			return ISLAND_LOOP
		Id.FRIEREN_HOUSE_LOOP:
			return FRIEREN_HOUSE_LOOP
		_:
			return NONE

