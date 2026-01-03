# Farming

A component-based farming simulation game built with **Godot 4.5** and **GDScript**. The project focuses on a small-but-solid foundation: an entity/component style for gameplay entities, a grid facade (`WorldGrid`) over persisted terrain + runtime occupancy, and a save system designed around capture/hydration.

## Features

- **Grid-based farming**: till soil, water, plant seeds, and simulate day ticks.
- **Plants with growth stages**: driven by `PlantData` resources and plant states.
- **Inventory + hotbar + tools**: data-driven item/tool resources with a player tool manager.
- **Save/load**: session autosaves + named slots, with separate level state vs global agents.
- **NPC foundation**: `AgentRegistry` + `AgentSpawner` to materialize global agent records as runtime nodes.

## Requirements

- **Godot 4.5** (the project uses `config/features=...("4.5", ...)` in `project.godot`)

## Run the game

- Open `project.godot` in Godot
- Press **F5** (Play)

## Controls

| Action | Key(s) |
| :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` / Arrow Keys |
| **Interact / Use Tool** | `E` |
| **Select Hotbar Slot** | `1` - `5` / Numpad `1` - `5` |
| **Pause** | `Esc` / `P` |

## Debugging (debug builds)

- **Toggle debug console**: press the apostrophe key (`'`)
  - When open, the console pauses the scene tree.
- **Useful commands**: `help`, `give`, `time`, `save`, `continue`, `save_slot`, `load_slot`, `slots`, `agents`, `save_dump*`

## Saving & loading (high level)

The game distinguishes between:

- **Session state**: autosave files under `user://sessions/current/`
- **Slots**: named saves under `user://saves/<slot>/` created by copying the session

The important split is:

- **Per-level state** (`LevelSave`): terrain deltas + entity snapshots owned by a level
- **Global agents** (`AgentsSave`): player + NPC records that persist across levels

See [Architecture](docs/architecture.md) for the current save model and ownership.

## Project structure

- `globals/`: autoload singletons (game flow, grid, save, events, agents, SFX/VFX)
- `entities/`: player/NPC/plants/items + reusable components
- `levels/`: level scenes + level root scripts
- `ui/`: HUD, hotbar, menus, loading screen
- `debug/`: debug grid overlay and in-game console
- `docs/`: architecture notes and system docs

## Documentation

- [Architecture (autoload map, save model, flow states)](docs/architecture.md)
- [Code organization (where to put code)](docs/code_organization.md)
- [Cutscene authoring rules](docs/cutscenes.md)

## Contributing

- Keep gameplay code decoupled via `EventBus` and the facades (`WorldGrid`, `SaveManager`)
- Prefer adding behavior via components under `entities/components/`

