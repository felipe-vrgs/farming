# Grid & TileMap System

This document explains how the project keeps the **grid model** independent from the **tilemap view**, while still supporting persistence + day simulation.

## Related docs

- [Architecture Overview](architecture.md)
- [Save System](save_system.md)

## Core architecture

The game separates **Logical Model** from **Visual View**:

```mermaid
graph TD
  WG[WorldGrid (Facade)] --> TS[TerrainState (Persisted)]
  WG --> OG[OccupancyGrid (Runtime)]
  TS -->|EventBus.terrain_changed| TMM[TileMapManager (View)]
  TMM --> Layers[TileMapLayer nodes]
```

### WorldGrid (facade)

**File:** `globals/grid/world_grid.gd`

`WorldGrid` is a thin facade that gives gameplay code a stable API while delegating to:

- **`TerrainState`**: persisted terrain deltas + day simulation + render events
- **`OccupancyGrid`**: runtime-only entity registration and queries

### TerrainState (persisted)

**File:** `globals/grid/terrain_state.gd`

`TerrainState` stores the delta between the authored level tilemap and the player's modifications (tilled soil, wet soil, cleared cells), and drives day simulation.

- **`TerrainCellData`** (`globals/grid/models/terrain_cell_data.gd`): delta state for a single cell
  - `terrain_id`: the terrain enum (grass/dirt/soil/wet/etc)
  - `terrain_persist`: whether the delta should be saved

### OccupancyGrid (runtime-only)

**File:** `globals/grid/occupancy_grid.gd`

`OccupancyGrid` tracks “who is on this cell?” for interaction and (future) AI/pathing. It is derived state rebuilt from components each load.

- `GridOccupantComponent` / `GridDynamicOccupantComponent` register entities on enter/exit
- Debug model helpers live under `globals/grid/models/` (e.g. `cell_occupancy_data.gd`)

### TileMapManager (view)

**File:** `globals/grid/tile_map_manager.gd`

`TileMapManager` listens to grid events (via `EventBus`) and updates the visual tilemap layers.

#### Typical layer structure

- **Ground**: base terrain (grass/dirt)
- **Soil overlay**: tilled soil visuals
- **Wet overlay**: wet soil visuals

#### “Touched cells” system (important for correctness)

To prevent “ghost tiles” when loading/reloading saves, `TileMapManager` tracks cells that have ever been modified:

- `_touched_cells`: which cells were changed at least once since boot
- `_original_ground_terrain`: captures the authored terrain the first time a cell is touched

On load, it can revert touched cells to their original ground terrain before applying the loaded deltas.

## Common interaction flow (hoe example)

1. Player uses a hoe.
2. Player `ToolManager` calls `WorldGrid.set_soil(cell)`.
3. `TerrainState` mutates the delta state and emits `EventBus.terrain_changed(...)`.
4. `TileMapManager` receives the event and updates the appropriate tilemap layer(s) for the affected cell(s).

## Debugging the grid

- `WorldGrid.debug_get_grid_data()` provides a merged view of terrain + occupancy for debug overlays.
- `DebugGrid` (autoload in debug builds) can render that information visually.

