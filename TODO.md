# Farming Game - Development Roadmap

## 1. Visuals & "Juice" (Priority)
*   [x] **VFX Refactor**: Centralize one-shot effects (hit particles, leaves falling) via `VFXManager`.
*   [x] **Hit Feedback**: Implement `HitFlashComponent` and shader for entities.
*   [ ] **Shader Improvements**:
    *   [ ] Improve "Wet Soil" visual (current luma-add shader) to look more natural.
    *   [ ] Add a separate "Wind/Sway" shader for plants and trees.
*   [ ] **Editor Tooling**: Make `VFX.gd` a `@tool` so effects can be previewed in the inspector.
*   [ ] **Screen Shake**: Implement a camera shake system for tool impacts.

## 2. Inventory & HUD
*   [x] **Data Structures**: `InventoryData` and `ItemData` Resources.
*   [x] **Loot Drops**: Entities spawn items (e.g., Wood from Trees) on destruction.
*   [x] **Item Pickups**: Basic `WorldItem` pickup logic (adds to inventory on collision).
*   [ ] **HUD/Hotbar**: Create a UI bar to visualize inventory and select tools/seeds.
*   [ ] **Pickup "Juice"**: Add a magnet/fly-to-player effect for world items.

## 3. Architecture & Systems
*   [x] **Generic Occupancy**: Multi-layered grid entities (plants, obstacles, etc.).
*   [ ] **Generic Interaction**: Refine `handle_tool()` on entities so tools don't need to know specific class types (Tree, Rock, etc).
*   [ ] **NPC/AI Foundation**: Basic pathfinding or scheduled movement for potential villagers.

## 4. Persistence (Save/Load)
*   [ ] **Grid Serialization**: Save/Load the state of every tile (terrain, growth, objects).
*   [ ] **Player State**: Save inventory, money, position, and current day.

## 5. Debugging & Tooling
*   [ ] **Grid Inspector**: Enhance `DebugGrid` to show metadata (Growth Stage, Health) on hover.
*   [ ] **Time Control**: Add a debug UI to skip days or pause time.
