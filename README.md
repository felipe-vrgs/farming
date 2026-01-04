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
| **Use Tool** | `E`, Mouse Left Button |
| **Interact** | `F`, Mouse Right Button |
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

### Linting / formatting

This repo uses **gdtoolkit**:
- `gdlint` (lint, enforced in CI)
- `gdformat` (format, enforced in CI via a non-mutating check)

Install dev tooling:

```bash
pip install -r requirements-dev.txt
```

Run checks:

```bash
python tools/ci/sanity_check.py
python tools/lint/lint.py
```

#### Recommended: use `make` (centralized commands)

```bash
# Repo sanity (autoload paths, docs, scene mapping)
make sanity

# Lint (gdlint)
make lint

# Format (apply)
make format

# Format (CI-style check: fails if formatting would change files)
make format-check
```

### Headless tests (regression checks)

This repo includes a minimal headless test runner for stable systems (save/load, simulation, runtime smoke).

Run (requires Godot installed):

```bash
# Option A: call Godot directly
godot --headless --scene res://tests/headless/test_runner.tscn

# Option B: Python wrapper (pass --godot if godot isn't on PATH)
python tools/tests/run_headless_tests.py
```

To include the runtime smoke suite (loads/changes scenes; slower/noisier):

```bash
python tools/tests/run_headless_tests.py --include-runtime
```

#### Running tests via `make`

```bash
# Unit-ish suites (fast)
make test

# Includes runtime smoke suite (slower/noisier; changes scenes)
make test-full
```

Windows (easy mode):

```bash
# Git Bash (example path) - no env vars needed
python tools/tests/run_headless_tests.py --godot "C:/path/to/Godot_v4.5-stable_win64.exe"

# Or CMD/PowerShell:
tools\\tests\\run_headless_tests.cmd "C:\\path\\to\\Godot_v4.5-stable_win64.exe"
```

Windows `make` note:

```bash
# Run via make by overriding GODOT_BIN (Git Bash paths)
make test GODOT_BIN="C:/Program Files/Godot/Godot.exe"
make test-full GODOT_BIN="C:/Program Files/Godot/Godot.exe"
```

Optional: enable automatic lint on commit via pre-commit:

```bash
pre-commit install
```
