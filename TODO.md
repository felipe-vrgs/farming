# Farming Game - Development Roadmap

## 1. Gameplay Systems
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
*   [ ] **Pause Game Feature**: Implement a proper pause menu and game state.
*   [ ] **Hand Interaction**: After refining handle tool improve hand flow (animation, behavior, icon, etc...)
*   [ ] **Objects**: Add other objects and tools (rocks, pickaxe ...)
*   [ ] **Harvest Rewards**: Hook `Plant` harvest to spawn items / add to inventory.
*   [ ] **Refactor Interaction**: Replace duck-typing in `ToolData` with Component-based interactions.
    *   Create `InteractableComponent` base.
    *   Implement specific interaction components (e.g., `DamageOnInteract`, `LootOnDeath`, `Waterable`) to remove logic from entity scripts.

## 2. UI & UX
*   [ ] **HUD/Hotbar**: Use proper UI pack and improve looks
*   [ ] **Inventory**: Create inventory screen
*   [ ] **UI Manager**: Create global UI handler via EventBus for spawning/managing UI elements (loading screens, menus, popups).
*   [ ] **Error Reporting**: Implement user-facing feedback for critical failures (e.g., Save/Load errors) instead of silent console warnings.

## 3. Architecture & Refactoring
*   [ ] **Standardize Saveable Interface**: Enforce `SaveComponent` as primary, remove duality with `get_save_state` on entities.
*   [ ] **Decouple Capture from GridState**: Pass `LevelRoot` to capture, making it the source of truth for entities (WYSWYG).
*   [ ] **Async Hydration**: Hydrate entities in chunks (coroutines) to prevent frame freeze on large levels.
*   [ ] **Strict Level IDs**: Use `LevelRegistry` or `Enums` for level IDs instead of raw strings to prevent typos.
*   [ ] **Dynamic Player Spawning**: Remove player from scene files, instantiate dynamically on level load to fix positioning race conditions.
*   [ ] **Extract Offline Simulation**: Move `compute_offline_day_for_level_save` out of `GameManager` into a dedicated `SimulationService` to reduce `GameManager` scope.
*   [ ] **Strict Initialization**: Replace lazy `ensure_initialized` chains with a deterministic `Bootstrap` scene/script to prevent initialization order bugs.
*   [ ] **Type Safety Audit**: Refactor generic `Array` and `Dictionary` usages to typed variants (e.g., `Array[GridCellData]`) for better autocomplete and safety.
