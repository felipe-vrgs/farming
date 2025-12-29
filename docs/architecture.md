# Architecture Overview

## Introduction
This document provides a high-level overview of the Farming Game architecture. The project is built using Godot 4.5+ and GDScript, leveraging a component-based architecture and robust state management for game entities.

## Core Architecture

The game relies on a set of **Autoloads (Singletons)** to manage global state and facilitate communication between systems.

### Core Singletons
- **GameManager**: The central conductor. Handles session management, level transitions, and "offline" simulation (calculating what happened while the game was closed or a level was unloaded).
- **EventBus**: A centralized signal hub that decouples systems. Entities emit signals here instead of referencing each other directly.
- **TimeManager**: Manages the in-game clock and day/night cycle. Emits `day_started` signals via the EventBus.
- **GridState**: The "Model" for the farming grid. It stores the state of every soil tile, plant, and object, independent of the visual TileMap.
- **SaveManager**: Handles serialization and deserialization of game state.

### System Diagram
```mermaid
graph TD
    GM[GameManager] -->|Controls| TM[TimeManager]
    GM -->|Manages| SM[SaveManager]
    GM -->|Updates| GS[GridState]
    
    TM -->|Emits day_started| EB[EventBus]
    
    Player[Player Entity] -->|Listens| EB
    Player -->|Interacts| GS
    
    GS -->|Updates| TMM[TileMapManager]
    GS -->|Notifies| EB
```

## Grid & Farming System

The farming system separates **Data** (GridState) from **Presentation** (TileMapManager/Nodes).

### Key Components
- **GridState**: Stores `GridCellData` for every coordinate. Handles logic like "can I plant here?" or "is this soil wet?".
- **GridCellData**: A data structure holding terrain type, moisture level, and references to entities occupying the cell.
- **GridOccupantComponent**: A component attached to entities (like Plants) that registers them with the `GridState` upon creation.
- **SimulationRules**: A helper class containing pure functions for game logic (e.g., `predict_soil_decay`, `predict_plant_growth`).

### Day Cycle Sequence
When a new day starts, the system updates the world state.

```mermaid
sequenceDiagram
    participant TM as TimeManager
    participant EB as EventBus
    participant GM as GameManager
    participant GS as GridState
    participant P as Plant Entity

    TM->>EB: emit day_started(day_index)
    EB->>GM: _on_day_started()
    GM->>GM: Autosave Session
    
    EB->>GS: _on_day_started()
    loop For each cell
        GS->>GS: Apply Soil Decay (Wet -> Dry)
        GS->>P: on_day_passed(is_wet)
        P->>P: Check growth conditions
        P->>P: Update State (Seed -> Growing)
    end
    
    GS->>EB: emit terrain_changed
```

## Entity Component System

Entities (Player, NPCs, World Items) are built using composition.

### Common Components
- **StateMachine**: Generic state machine implementation.
- **HealthComponent**: Manages health and death.
- **GridOccupantComponent**: Registers the entity on the grid.
- **RayCellComponent**: Detects the grid cell the entity is facing/aiming at.
- **ShakeComponent**: Handles visual feedback (recoil, damage).

## Player Controller

The Player uses a State Machine to handle actions.

### Player States
- **Idle**: Waiting for input.
- **Walk**: Moving.
- **ToolSwing**: Using a tool (Axe, Pickaxe).
- **ToolCharging**: Charging a tool for a stronger effect.

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Walk : Input
    Walk --> Idle : No Input
    
    Idle --> ToolCharging : Hold Use
    Walk --> ToolCharging : Hold Use
    
    ToolCharging --> ToolSwing : Release
    ToolSwing --> Idle : Animation Finish
```

## Inventory System

The inventory system is data-driven using Resources.

- **InventoryData**: Holds a list of `InventorySlot`s.
- **InventorySlot**: Holds an `ItemData` reference and a count.
- **ItemData**: A `Resource` defining item properties (name, icon, stack limit).
- **ToolData**: Inherits `ItemData`, adds specific tool properties (damage, energy cost).

## Data Persistence (Save System)

The save system uses `ResourceSaver` and `ResourceLoader` with custom `Resource` classes acting as DTOs (Data Transfer Objects).

- **GameSave**: Meta-information (current day, active level).
- **LevelSave**: State of a specific level (grid data, entity positions).
- **SaveComponent**: Attached to entities to automatically serialize their state into the `LevelSave`.

