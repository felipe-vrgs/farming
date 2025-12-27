# Farming Game - Development Roadmap

## 1. Gameplay Systems
*   [x] **Plant State Machine**: Refactor `Plant` logic into robust states:
    *   `Seed`: Initial planting animation.
    *   `Growing`: Handles daily updates.
    *   `Mature`: Harvest interaction logic.
    *   `Withered`: For dead plants.
*   [x] **Day Tick (Plants + Soil)**: On `EventBus.day_started`, wet soil dries and plants advance growth only if watered.
*   [ ] **Generic Interaction**: Refine `handle_tool()` so tools work on generic `Interactable` components rather than specific classes.
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
*   [ ] **Pause Game Feature**: Implement a proper pause menu and game state.
*   [ ] **Hand Interaction**: After refining handle tool improve hand flow (animation, behavior, icon, etc...)
*   [ ] **Objects**: Add other objects and tools (rocks, pickaxe ...)
*   [ ] **Harvest Rewards**: Hook `Plant` harvest to spawn items / add to inventory.

## 2. UI & UX
*   [X] **HUD/Hotbar**: Create a UI bar to visualize inventory and select tools/seeds.
*   [x] **HUD/Hotbar**: Improve UI for HUD and make it cleaner, add fixed slots (or maybe make it data controlled, so we can easily change later)
*   [x] **Grid Inspector**: Enhance `DebugGrid` to show metadata (Growth Stage, Health) on hover.
*   [] **Inventory**: Create inventory screen

## 3. Persistence
*   [x] **Grid Serialization (Baseline v1)**: `SaveGame` Resource + `SaveManager` autoload + serializers (`save/serializers/`) for terrain + grid entities.
*   [x] **Entity Snapshots**: Add save/load for new entity types (e.g. rocks) via `get_save_state()/apply_save_state()`.
*   [ ] **Player State**: Save inventory, money, position, equipped tool. **(Wait for Inventory System)**.
*   [ ] **Save Slots + Autosave**: Multiple files under `user://saves/` + optional autosave on sleep/day change.
*   [ ] **Refactor Serializer Access**: Expose public `GridState` methods (e.g. `get_plants_root`) to avoid private access in `EntitySerializer`.
*   [ ] **Save Versioning/Migrations**: Bump `SaveGame.version` and migrate old saves safely.
*   [x] **Save/Load Debug Controls**: Add temporary hotkeys (e.g. F5 save, F9 load) or `GameConsole` commands.
*   [x] **World Bounds / Delta Saving**: Decide whether to save only touched cells (`_grid_data`) or define bounds + persist all relevant cells.
*   [x] **FIX**: Fix game loading for tiles (not reverting tiles properly)
*   [ ] **Load Order Safety**: Ensure entity `queue_free()` completes before re-spawn (add `await process_frame` in `SaveManager`) to avoid duplicates.
*   [ ] **Missing Asset Handling**: If a saved `scene_path` no longer exists, gracefully skip + report (don’t hard-fail load).
