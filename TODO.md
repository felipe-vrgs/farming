# Farming Game - Development Roadmap

## 1. Gameplay Systems
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
    *   Implement time-based schedules (start_time + duration) so NPC routines don't depend on offline tick frequency.
    *   Author shared level routes (Path2D/waypoints) and reference them from schedules.
    *   ✅ AgentSpawner: spawn/despawn NPCs based on AgentRegistry + active level (current stage).
    *   [ ] **Tomorrow plan (NPC walking simulator)**:
        *   Wire an NPC base scene (visuals + movement controller) and create NPC variants.
        *   Implement a simple “walk route” behavior online (Path2D sampling / waypoint steering).
        *   Add schedule data model (step_started_at + duration) and drive progress from global time.
        *   Add offline simulation step that updates AgentRecord (`current_level_id`, `last_world_pos`, `last_spawn_id`) when level is unloaded.
        *   Add debug commands to force NPC travel / force schedule step for rapid iteration.
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

## 3. Scalability & Performance [ONLY IF NEEDED]
*   [ ] **Async Hydration**: Hydrate entities in chunks (coroutines) to prevent frame freeze on large levels.
*   [ ] **Strict Initialization**: Replace lazy `ensure_initialized` chains with a deterministic `Bootstrap` scene/script to prevent initialization order bugs.
