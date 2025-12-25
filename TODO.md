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

## 2. UI & UX
*   [ ] **HUD/Hotbar**: Create a UI bar to visualize inventory and select tools/seeds.
*   [ ] **Grid Inspector**: Enhance `DebugGrid` to show metadata (Growth Stage, Health) on hover.

## 3. Persistence
*   [x] **Grid Serialization (Baseline v1)**: `SaveGame` Resource + `SaveManager` autoload + `GridState.save_world()/load_world()` for terrain + grid entities.
*   [ ] **Entity Snapshots**: Add save/load for new entity types (e.g. rocks) via `get_save_state()/apply_save_state()`.
*   [ ] **Player State**: Save inventory, money, position, equipped tool, and current day.
*   [ ] **Save Slots + Autosave**: Multiple files under `user://saves/` + optional autosave on sleep/day change.
*   [ ] **Save Versioning/Migrations**: Bump `SaveGame.version` and migrate old saves safely.

## Suggested Next Features (High Impact)
*   [ ] **Rocks**: Add rock entities (multi-hit, drops) + save/load snapshot.
*   [ ] **Harvest Rewards**: Hook `Plant` harvest to spawn items / add to inventory.
*   [ ] **Grid Inspector Hover**: In `DebugGrid`, show full cell info on hover (terrain, occupants, plant stage/days, tree HP).
