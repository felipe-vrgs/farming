# Code Review & Suggestions

## Overview
This document outlines findings from a review of the codebase, highlighting strengths and areas for potential improvement.

## Strengths

1.  **Architecture**: The separation of **GridState** (Model) and **TileMapManager** (View) is excellent. It allows for complex logic (soil moisture, growth) without tying it to the visual representation limitations.
2.  **Decoupling**: Extensive use of `EventBus` prevents tight coupling between systems.
3.  **Composition**: The entity system uses components effectively (`GridOccupantComponent`, `SaveComponent`), promoting code reuse.
4.  **Data-Driven Design**: Heavy use of `Resource` files for items, plants, and tools makes balancing and content creation easy.

## Observations & Suggestions

### 1. GameManager Responsibilities
**Observation**: `GameManager` is currently handling:
- Session lifecycle (New Game, Continue)
- Level transition logic
- Autosaving coordination
- Offline time simulation (calculating plant growth while away)

**Suggestion**: Consider splitting the "Offline Simulation" logic into a dedicated helper or service, e.g., `SimulationService`. `GameManager` is approaching "God Object" status.

### 2. Hydration Performance & Source of Truth
**Observation**: `LevelHydrator` instantiates all entities in a single loop (`hydrate_entities`). On a large farm, this will cause a noticeable freeze. Additionally, capture relies heavily on `GridState`'s internal data.
**Refers to TODO**:
- `[ ] Async Hydration`
- `[ ] Decouple Capture from GridState`

**Suggestion**: Implement a coroutine-based hydration that yields execution every N milliseconds to keep the UI responsive (Async Hydration). Refactor capture to iterate over the Scene Tree (via `LevelRoot`) rather than `GridState` to ensure what you see is what you get.

### 3. Interaction Logic (Duck Typing)
**Observation**: Tool interactions often rely on checking specific class types or method existence (duck typing). This makes it hard to add new interactable objects without modifying the tool logic.
**Refers to TODO**:
- `[ ] Refactor Interaction`: Replace duck-typing with `InteractableComponent`.

**Suggestion**: Create specific interaction components (e.g., `DamageableComponent`, `WaterableComponent`). The tool should just look for the component, not the entity type.

### 4. Initialization Order
**Observation**: `GridState` and other globals use a `ensure_initialized()` pattern. While robust, it can mask initialization order issues.
```gdscript
# grid_state.gd
func ensure_initialized() -> bool:
    if not TileMapManager.ensure_initialized():
        return false
```
**Suggestion**: Ensure strict reliance on `_ready` or a dedicated `Bootstrap` scene/script that initializes systems in a deterministic order if this becomes complex to debug.

### 5. Magic Strings & Level IDs
**Observation**: String literals are used for groups and level IDs.
**Refers to TODO**:
- `[ ] Strict Level IDs`
**Suggestion**: Create a `LevelRegistry` or static `LevelIDs` class to manage these constants.

### 6. Save System Consistency
**Observation**: The save system checks both the entity and a potential `SaveComponent` for state methods.
**Refers to TODO**:
- `[ ] Standardize Saveable Interface`
**Suggestion**: Deprecate `entity.get_save_state()` and enforce `SaveComponent` as the single source of truth for serialization.