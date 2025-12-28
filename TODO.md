# Farming Game - Development Roadmap

## 1. Gameplay Systems
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
*   [ ] **Pause Game Feature**: Implement a proper pause menu and game state.
*   [ ] **Hand Interaction**: After refining handle tool improve hand flow (animation, behavior, icon, etc...)
*   [ ] **Objects**: Add other objects and tools (rocks, pickaxe ...)
*   [ ] **Harvest Rewards**: Hook `Plant` harvest to spawn items / add to inventory.
*   [ ] **Refactor Interaction**: Replace duck-typing in `ToolData` with Component-based interactions.
    *   Create `InteractableComponent` base.
    *   Implement specific interaction components (e.g., `DamageOnInteract`, `LootOnDeath`) to remove logic from entity scripts.

## 2. UI & UX
*   [] **HUD/Hotbar**: Use proper UI pack and improve looks
*   [] **Inventory**: Create inventory screen

## 3. Persistence
*   [ ] **Player State**: Save inventory, money, position, equipped tool. **(Wait for Inventory System)**.
*   [ ] **Save Slots + Autosave**: Multiple files under `user://saves/` + optional autosave on sleep/day change.
*   [ ] **Refactor Serializer Access**: Expose public `GridState` methods (e.g. `get_plants_root`) to avoid private access in `EntitySerializer`.
*   [ ] **Refactor Saving**: Implement "Self-Saving" Components strategy (distributed state saving) to replace manual `get_save_state` methods.
    *   Create base `SaveableComponent` or interface.
    *   Update `EntitySerializer` to crawl for saveable children.
    *   Create `PropertySaver` for generic parent property reflection.