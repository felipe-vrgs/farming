# Farming Game - Development Roadmap

## 1. Visuals & "Juice" (Priority)
*   [ ] **VFX Refactor**: Centralize one-shot effects (hit particles, leaves falling) so they can be easily triggered and previewed.
*   [ ] **Shader Improvements**:
    *   Add a "Hit Flash" shader to `Tree` and `Plant` for better feedback when struck.
    *   Improve the "Wet Soil" visual (current luma-add shader) to look more natural.
*   [ ] **Editor Tooling**: Make `ToolHitParticles.gd` a `@tool` so VFX can be tested in the Godot inspector without launching the game.

## 2. Inventory & Loot
*   [ ] **Data Structures**: Implement `InventoryData` and `ItemData` Resources.
*   [ ] **Loot Drops**: Update the `Tree` to spawn `Wood` items when its health reaches zero.
*   [ ] **HUD**: Create a basic inventory bar (Hotbar) to select tools and seeds.

## 3. Architecture Refactoring
*   [ ] **Generic Occupancy**: Move `GridCellData` away from hardcoded `plant_id`/`obstacle_node` and toward a layered `occupants` dictionary.
*   [ ] **Signal Decoupling**: Use a more robust event bus or signals for world interactions to reduce the direct dependency between `Player` and `GridState`.

## 4. Persistence (Save/Load)
*   [ ] **Grid Serialization**: Save the state of every tile (terrain, growth, objects) to a file.
*   [ ] **Player State**: Save inventory, money, and position.

## 5. Debugging Tools
*   [ ] **Grid Inspector**: Enhance the `DebugGrid` to show metadata (Growth Stage, Health) on hover.

