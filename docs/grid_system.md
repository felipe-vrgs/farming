# Grid & TileMap System

## Architecture
The Farming Game separates the **Logical Model** (Grid) from the **Visual View** (TileMap) to allow for complex simulation without being tied to rendering constraints.

```mermaid
graph TD
    Logic[WorldGrid (Facade)] <-->|Calls| Terrain[TerrainState (Persisted)]
    Logic <-->|Calls| Occ[OccupancyGrid (Runtime)]
    Terrain <-->|Events| View[TileMapManager (View)]
    View -->|Manipulates| Layers[TileMapLayers]
```

## WorldGrid (Facade)
**File:** `globals/grid/world_grid.gd`

`WorldGrid` is a thin facade that exposes a stable API to gameplay code (tools, components) while delegating to two internal subsystems:

- `TerrainState`: persisted terrain deltas + simulation triggers
- `OccupancyGrid`: runtime-only entity registration and queries

## TerrainState (Persisted)
**File:** `globals/grid/terrain_state.gd`

This singleton maintains the persisted terrain delta state (only tiles that differ from the authored TileMap), and drives farm simulation on day ticks (e.g., wet soil drying, plant day pass).

*   **TerrainCellData**: Holds the state of a single tile's terrain delta.
    *   `terrain_id`: Enum (GRASS, DIRT, SOIL, SOIL_WET).
    *   `terrain_persist`: true if this terrain should be saved (delta from authored tilemap).

## OccupancyGrid (Runtime)
**File:** `globals/grid/occupancy_grid.gd`

This singleton maintains runtime-only occupancy (which entities occupy a cell, and which entity types block interactions/movement). It is rebuilt from `GridOccupantComponent` / `GridDynamicOccupantComponent` each time a level loads.

## TileMapManager (The View)
**File:** `globals/grid/tile_map_manager.gd`

This singleton handles the visual representation using Godot's `TileMapLayer` nodes.

### Layer Structure
1.  **Ground Layer**: The base terrain (Grass, Dirt).
2.  **Soil Overlay**: Uses `TerrainSets` to draw tilled soil on top of the ground.
3.  **Wet Overlay**: Draws the darker "wet" soil texture on top of the soil.

### The "Touched Cells" System
To support a persistent world on top of a static level design, `TileMapManager` tracks **Touched Cells**.

1.  **Modification**: When the player digs, the cell is added to `_touched_cells`.
2.  **Original State**: The manager remembers what the ground *was* before modification (`_original_ground_terrain`).
3.  **Reversion**: When loading a save, or resetting the level, the manager can revert these specific cells to their original state before applying the new save data. This prevents "ghost" tiles from persisting between save loads.

## Interaction Flow
1.  Player uses Hoe on a tile.
2.  `ToolManager` (via `ToolData`) calls `WorldGrid.set_soil(cell)`.
3.  `TerrainState` updates the terrain delta and emits `terrain_changed`.
5.  `TileMapManager` listens for `terrain_changed`.
6.  `TileMapManager` updates the `SoilOverlay` layer for that cell.

