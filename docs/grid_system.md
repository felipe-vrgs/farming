# Grid & TileMap System

## Architecture
The Farming Game separates the **Logical Model** (Grid) from the **Visual View** (TileMap) to allow for complex simulation without being tied to rendering constraints.

```mermaid
graph TD
    Logic[GridState (Model)] <-->|Events| View[TileMapManager (View)]
    Logic -->|Stores| Data[GridCellData]
    View -->|Manipulates| Layers[TileMapLayers]
```

## GridState (The Model)
**File:** `globals/grid_state.gd`

This singleton maintains the "Truth" of the world. It stores a dictionary `_grid_data` mapping `Vector2i` coordinates to `GridCellData` objects.

*   **GridCellData**: Holds the state of a single tile.
    *   `terrain_id`: Enum (GRASS, DIRT, SOIL, SOIL_WET).
    *   `entities`: Dictionary of entities occupying this tile (Plants, Obstacles).
*   **Logic**: Handles rules like "Can I plant here?" (Is it soil? Is it empty?).
*   **Simulation**: When a day passes, `GridState` iterates over all data to dry out soil and trigger plant growth.

## TileMapManager (The View)
**File:** `globals/tile_map_manager.gd`

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
2.  `ToolManager` calls `GridState.set_soil(cell)`.
3.  `GridState` updates `GridCellData.terrain_id` to `SOIL`.
4.  `GridState` emits `terrain_changed`.
5.  `TileMapManager` listens for `terrain_changed`.
6.  `TileMapManager` updates the `SoilOverlay` layer for that cell.

