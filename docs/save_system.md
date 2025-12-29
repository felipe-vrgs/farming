# Save System: Capture & Hydration

## Overview
The Save System is responsible for persisting the state of the game world. It distinguishes between **Session State** (what's currently happening in the active game loop) and **Disk State** (what's written to `user://`).

The core concept is **Capture** (Serialization) and **Hydration** (Deserialization).

```mermaid
graph LR
    Runtime[Runtime World] -->|Capture| Snapshot[LevelSave (Resource)]
    Snapshot -->|Save| Disk[Disk (.tres)]
    Disk -->|Load| Snapshot
    Snapshot -->|Hydrate| Runtime
```

## Level Capture
**File:** `world/capture/level_capture.gd`

When a level is unloaded (or the game is saved), the `LevelCapture` static class is invoked. It orchestrates the capture of two main data streams:

1.  **Terrain Data**: The state of the grid cells (Soil, Wet Soil, etc.).
2.  **Entity Data**: The state of dynamic objects (Plants, Dropped Items).

### Entity Capture Process
**File:** `world/capture/entity_capture.gd`

The system iterates through the `GridState` to find registered entities.

1.  **Deduping**: It uses `instance_id` to ensure multi-cell entities (like big trees) are only saved once.
2.  **Snapshot Creation**: Creates an `EntitySnapshot` object containing:
    *   `scene_path`: Resource path to the `.tscn` file.
    *   `grid_pos`: Where it is on the grid.
    *   `state`: A dictionary of arbitrary data (growth stage, health, etc.).
3.  **State Extraction**:
    *   Checks if the entity has `get_save_state()`.
    *   **Fallback**: Checks if a `SaveComponent` exists and has `get_save_state()`.

## Level Hydration
**File:** `world/hydrate/level_hydrator.gd`

When a level is loaded, the `LevelHydrator` reconstructs the world from a `LevelSave`.

1.  **Cleanup**: Calls `clear_dynamic_entities()` to remove any "leftover" dynamic objects from the previous state (or default scene state).
2.  **Terrain Rebuild**: Updates `GridState` and `TileMapManager` to match the saved cell data.
3.  **Entity Rebuild**:
    *   **Reconciliation**: Checks for **Persistent Entities** (entities placed in the Godot Editor, like pre-placed trees). If an entity in the save matches a persistent ID in the scene, it updates that existing node instead of spawning a new one.
    *   **Instantiation**: For dynamic entities (crops planted by the player), it loads the `scene_path` and `instantiate()`s the node.
    *   **State Application**: Calls `apply_save_state(data)` on the entity or its `SaveComponent`.

### Key Challenges & TODOs
*   **Performance**: Hydration happens synchronously. A large farm with hundreds of plants will cause a frame freeze on load.
    *   *Reference TODO*: "Async Hydration: Hydrate entities in chunks".
*   **Source of Truth**: Currently, capture relies heavily on `GridState`. This can be fragile if entities exist in the scene but aren't correctly registered on the grid.
    *   *Reference TODO*: "Decouple Capture from GridState".

## Data Models
The system uses custom Resources as Data Transfer Objects (DTOs).

*   **GameSave**: Global session data (Current Day, Active Level ID).
*   **LevelSave**: Per-level data.
    *   `cells`: Dictionary[Vector2i, int] (Terrain Types)
    *   `entities`: Array[EntitySnapshot]
    *   `player_pos`: Vector2
*   **EntitySnapshot**:
    *   `scene_path`: String
    *   `state`: Dictionary
    *   `persistent_id`: StringName (for editor-placed entity reconciliation)

