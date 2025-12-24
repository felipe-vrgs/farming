# Farming Game - Development Roadmap

## 1. Gameplay Systems
*   [ ] **Plant State Machine**: Refactor `Plant` logic into robust states:
    *   `Seed`: Initial planting animation.
    *   `Growing`: Handles daily updates.
    *   `Mature`: Harvest interaction logic.
    *   `Withered`: For dead plants.
*   [ ] **Generic Interaction**: Refine `handle_tool()` so tools work on generic `Interactable` components rather than specific classes.
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
*   [ ] **Pause Game Feature**: Implement a proper pause menu and game state.

## 2. UI & UX
*   [ ] **HUD/Hotbar**: Create a UI bar to visualize inventory and select tools/seeds.
*   [ ] **Grid Inspector**: Enhance `DebugGrid` to show metadata (Growth Stage, Health) on hover.

## 3. Persistence
*   [ ] **Grid Serialization**: Save/Load the state of every tile (terrain, growth, objects).
*   [ ] **Player State**: Save inventory, money, position, and current day.
