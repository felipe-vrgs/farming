# Farming Game - Development Roadmap

## 1. Core Mechanics & "Juice"
*   [x] **Enhance Tool Feedback**: Add cooldowns, "use/success/fail" sounds, and visual effects (particles/wind).
    *   [x] Refactor Tool Logic to Player State Machine (Idle -> ToolCharging -> ToolSwing).
    *   [x] Add Charging state visuals/logic.
    *   [x] Add Swing/Impact effects.
*   [x] **Screen Shake**: Implement a camera shake system for tool impacts.
*   [ ] **Pickup "Juice"**: Add a magnet/fly-to-player effect for world items.
*   [x] **Better Dust**: Improve the 4x4 rounded particle look to be more "puffy" or cloud-like using texture variants.
*   [ ] **Shader Improvements**:
    *   [ ] Add a separate "Wind/Sway" shader for plants and trees.

## 2. Gameplay Systems
*   [ ] **Plant State Machine**: Refactor `Plant` logic into robust states:
    *   `Seed`: Initial planting animation.
    *   `Growing`: Handles daily updates.
    *   `Mature`: Harvest interaction logic.
    *   `Withered`: For dead plants.
*   [ ] **Generic Interaction**: Refine `handle_tool()` so tools work on generic `Interactable` components rather than specific classes.
*   [ ] **NPC/AI Foundation**: Basic pathfinding and scheduled movement for villagers.
*   [ ] **Pause Game Feature**: Implement a proper pause menu and game state.

## 3. UI & UX
*   [ ] **HUD/Hotbar**: Create a UI bar to visualize inventory and select tools/seeds.
*   [ ] **Grid Inspector**: Enhance `DebugGrid` to show metadata (Growth Stage, Health) on hover.

## 4. Persistence
*   [ ] **Grid Serialization**: Save/Load the state of every tile (terrain, growth, objects).
*   [ ] **Player State**: Save inventory, money, position, and current day.
