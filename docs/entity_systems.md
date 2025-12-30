# Entity Systems (Plants, Tools, Items, Player)

This document summarizes how gameplay entities are structured under `entities/` and how “behavior” is attached via reusable components.

## Related docs

- [Architecture Overview](architecture.md)
- [Grid System](grid_system.md)
- [Save System](save_system.md)
- [AgentRegistry & NPC Simulation](agent_registry_and_npc_simulation.md)

## Composition-first entity design

Instead of deep inheritance, entities are built as scenes/scripts with small components under `entities/components/`.

### Common components

- **`GridOccupantComponent`** (`entities/components/grid_occupant_component.gd`)
  - Registers a static occupant into `WorldGrid`/`OccupancyGrid` so interactions can query “who is on this cell?”
- **`GridDynamicOccupantComponent`** (`entities/components/grid_dynamic_occupant_component.gd`)
  - Same idea, but designed for moving entities and emits `EventBus.occupant_moved_to_cell`.
- **`SaveComponent`** (`entities/components/save_component.gd`)
  - Provides `get_save_state()` / `apply_save_state(...)` style hooks for capture/hydration.
- **`RayCellComponent`** (`entities/components/raycell_component.gd`)
  - Helps the player/controller determine the targeted grid cell for tools/interactions.
- **`AgentComponent`** (`entities/components/agent_component.gd`)
  - Adds global identity to a node (`agent_id`, `kind`) so `AgentRegistry` can persist it.
- **`PersistentEntityComponent`** (`entities/components/persistent_entity_component.gd`)
  - Provides a stable persistent id for editor-placed entities to reconcile on load.

## Plants

**Entity:** `entities/plants/plant.tscn` / `entities/plants/plant.gd`

Plants are grid-owned entities that grow over day ticks.

### PlantData

**Resource:** `entities/plants/types/plant_data.gd` (e.g. `entities/plants/types/tomato.tres`)

`PlantData` defines things like:

- growth stage timings / thresholds
- sprite/animation data

### Growth logic (day driven)

1. `TimeManager` emits `EventBus.day_started(day_index)`.
2. `GameManager` calls `WorldGrid.apply_day_started(day_index)`.
3. `TerrainState` applies simulation and notifies relevant entities (e.g. plants) of day progression.
4. Plant state scripts under `entities/plants/states/` (`seed.gd`, `growing.gd`, `mature.gd`, `withered.gd`) advance based on the current conditions (wet soil, etc.).

## Tools (hand tool + tool data)

### Runtime “hand tool” node

**Entity:** `entities/tools/tool.tscn` / `entities/tools/tool.gd`

This is the visual + timing layer for using a tool (animations, orientation, VFX hooks).

### ToolData resources

**Resource script:** `entities/tools/data/tool_data.gd`

Tool resources (e.g. `entities/tools/data/axe.tres`, `watering_can.tres`) define:

- energy/stamina costs (if enabled)
- tool type/category (hoe, watering can, axe, etc.)
- area-of-effect sizing

The player’s tool logic lives under:

- `entities/player/scripts/tool_manager.gd`

## Items (inventory + world items)

- **Inventory models**: `entities/inventory/inventory_data.gd`, `inventory_slot.gd`
- **Item data**: `entities/items/resources/item_data.gd` (and item `.tres` resources)
- **World pickup**: `entities/items/world_item.tscn` / `world_item.gd`

## Player

**Entity:** `entities/player/player.tscn` / `entities/player/player.gd`

The player uses the shared state machine system under:

- `entities/state_machine/`

Player-specific states live under:

- `entities/player/states/` (`idle.gd`, `walk.gd`, `tool_charging.gd`, `tool_swing.gd`, etc.)

## Planned refactors (tracked in TODO)

See `TODO.md` for the up-to-date backlog, especially:

- componentized interactions (reduce tool-specific checks)
- save/capture consistency (lean on `SaveComponent` everywhere)

