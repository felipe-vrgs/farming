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
*   [x] **Grid Split (Terrain vs Occupancy)**: Implemented `TerrainState` (persisted deltas + render events) and `OccupancyGrid` (runtime-only entity registration/queries). Added `WorldGrid` facade (renamed from `GridState`) and moved grid code under `globals/grid/`.
*   [x] **Agent Registry + Event-driven Travel**: Added `AgentRegistry` autoload (tracks `agent_id`, `kind`, `current_level_id`, last pos/cell). `TravelZone` now emits a travel request event; Player handler performs scene change/spawn, NPC handler updates registry without changing the active scene.
*   [ ] **Strict Initialization**: Replace lazy `ensure_initialized` chains with a deterministic `Bootstrap` scene/script to prevent initialization order bugs.
*   [ ] **Type Safety Audit**: Refactor generic `Array` and `Dictionary` usages to typed variants (e.g., `Array[GridCellData]`) for better autocomplete and safety.

## 4. Scalability & Performance
*   [ ] **Async Hydration**: Hydrate entities in chunks (coroutines) to prevent frame freeze on large levels.
