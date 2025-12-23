# Farming Game - Development Roadmap

## 1. Visuals & "Juice" (Priority)
*   [x] **VFX Refactor**: Centralize one-shot effects (hit particles, leaves falling) so they can be easily triggered and previewed.
*   [ ] **Shader Improvements**:
    *   [x] Add a "Hit Flash" shader to `Tree` and `Plant` for better feedback when struck.
    *   [ ] Improve the "Wet Soil" visual (current luma-add shader) to look more natural.
*   [x] **Editor Tooling**: Make `VFXInstance.gd` a `@tool` so VFX can be tested in the Godot inspector without launching the game.

## 2. Inventory & Loot
*   [x] **Data Structures**: Implement `InventoryData` and `ItemData` Resources.
*   [x] **Loot Drops**: Update the `Tree` to spawn `Wood` items when its health reaches zero.
*   [ ] **HUD**: Create a basic inventory bar (Hotbar) to select tools and seeds.

## 3. Architecture Refactoring
*   [x] **Generic Occupancy**: Move `GridCellData` away from hardcoded `plant_id`/`obstacle_node` and toward a layered `grid_entities` dictionary.
*   [ ] **Signal Decoupling**: Use a more robust event bus or signals for world interactions to reduce the direct dependency between `Player` and `GridState`.
*   [ ] **Tool/Entity Compatibility**: Further refine the `Enums.EntityType` matching for tools like Pickaxes (Rocks) or Hammers (Furniture).

## 4. Persistence (Save/Load)
*   [ ] **Grid Serialization**: Save the state of every tile (terrain, growth, objects) to a file.
*   [ ] **Player State**: Save inventory, money, and position.

## 5. Debugging Tools
*   [ ] **Grid Inspector**: Enhance the `DebugGrid` to show metadata (Growth Stage, Health) on hover.
