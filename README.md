# Farming Game

A component-based farming simulation game built with Godot 4.5+ and GDScript. This project features a robust entity component system, grid-based farming mechanics, and a data-driven inventory system.

## 🌟 Features

- **Grid-Based Farming**: Plant seeds, water crops, and watch them grow over time.
- **Dynamic Growth System**: Plants have growth stages (Seed -> Sprout -> Mature) affected by soil conditions.
- **Day/Night Cycle**: Manage your time effectively as the world updates each day.
- **Inventory & Tools**: Use tools like the Axe, Hoe, and Watering Can, and manage resources in your inventory.
- **Entity Component System (ECS)**: Flexible architecture using composition for entities (Player, NPCs, Items).
- **Save System**: Persistent world state that saves grid data, entity positions, and player progress.

## 🛠️ Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    ```
2.  **Open in Godot:**
    - Launch Godot Engine (version 4.5 or higher).
    - Click "Import" and select the `project.godot` file in the cloned directory.
3.  **Run the Game:**
    - Click the "Play" button (or press F5) to start the game.

## 🎮 Controls

| Action | Key(s) |
| :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` / Arrow Keys |
| **Interact / Use Tool** | `E` |
| **Select Hotbar Slot** | `1` - `5` / Numpad `1` - `5` |
| **Pause** | `Esc` / `P` |

## 🏗️ Architecture

This project prioritizes modularity and separation of concerns.

### Core Systems
- **GameManager**: Central coordinator for session management and level transitions.
- **EventBus**: Global signal hub for decoupled communication between systems.
- **WorldGrid**: Facade API for gameplay code over `TerrainState` (persisted terrain deltas) + `OccupancyGrid` (runtime occupancy).
- **TileMapManager**: Tile rendering/view system (listens to terrain events).
- **TimeManager**: Handles the in-game clock and day/night cycle events.

### Entity Component System
Entities are built by composing small, single-purpose components:
- `GridOccupantComponent`: Registers entities on the farming grid.
- `HealthComponent`: Manages entity health and damage.
- `SaveComponent`: Handles state serialization for the save system.
- `StateMachine`: Manages complex entity behaviors (e.g., Player states: Idle, Walk, ToolSwing).

For more detailed documentation, check the `docs/` folder:
- [Architecture Overview](docs/architecture.md)
- [Entity Systems](docs/entity_systems.md)
- [Grid System](docs/grid_system.md)

## 🤝 Contributing

1.  Create a new branch for your feature or fix.
2.  Follow the existing code style (GDScript).
3.  Ensure new entities use the component system.
4.  Submit a Pull Request.

## 📄 License

[MIT License](LICENSE) (or appropriate license)

