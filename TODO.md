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
*   [] **UI Manager**: Create global UI handler via EventBus for spawning/managing UI elements (loading screens, menus, popups).
