# Farming Game - Development Roadmap

## 1. Gameplay Systems
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
*   [ ] **Pause Game Feature**: Implement a proper pause menu and game state.
*   [ ] **Hand Interaction**: After refining handle tool improve hand flow (animation, behavior, icon, etc...)
*   [ ] **Objects**: Add other objects and tools (rocks, pickaxe ...)
*   [ ] **Harvest Rewards**: Hook `Plant` harvest to spawn items / add to inventory.
*   [ ] **Refactor Interaction**: Replace duck-typing in `ToolData` with `InteractableComponent`.

## 2. UI & UX
*   [] **HUD/Hotbar**: Use proper UI pack and improve looks
*   [] **Inventory**: Create inventory screen

## 3. Persistence
*   [ ] **Player State**: Save inventory, money, position, equipped tool. **(Wait for Inventory System)**.
*   [ ] **Save Slots + Autosave**: Multiple files under `user://saves/` + optional autosave on sleep/day change.
*   [ ] **Refactor Serializer Access**: Expose public `GridState` methods (e.g. `get_plants_root`) to avoid private access in `EntitySerializer`.
*   [ ] **Refactor Saving**: Replace duck-typing in `EntitySerializer` with `SaveComponent` logic.
*   [ ] **Save Versioning/Migrations**: Bump `SaveGame.version` and migrate old saves safely.
*   [ ] **Load Order Safety**: Ensure entity `queue_free()` completes before re-spawn (add `await process_frame` in `SaveManager`) to avoid duplicates.
*   [ ] **Missing Asset Handling**: If a saved `scene_path` no longer exists, gracefully skip + report (don’t hard-fail load).