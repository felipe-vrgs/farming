# Architecture (current)

This document describes the **actual** architecture as it exists today in the repo (Godot **4.5**, GDScript).

## High-level model

The project uses a **global-autoload spine** (services) + **scene-local gameplay nodes** (`game/entities/` + `game/levels/`) connected via **`EventBus` signals**.

- **Autoloads** own long-lived state and orchestration (save/load, flow, time, grid, agents, dialogue, UI).
- **Levels** are normal scenes (`game/levels/*.tscn`) with a `LevelRoot` script that exposes a stable `level_id`.
- **Entities** are reusable scenes/scripts (player/NPC/plants/items) built from **components** and **state machines**.

## Autoload map (who owns what)

Defined in `project.godot` under `[autoload]`.

### Core orchestration

- **`Runtime`** (`game/globals/game_flow/game_runtime.gd`)
  - Owns: save/load pipeline, level changes, boot binding to active level, offline day simulation for non-active levels.
  - Delegates to: `SaveManager`, `GameFlow`, `FlowStateManager`, `SceneLoader`.
  - Provides cutscene helpers: `find_cutscene_anchor`, `find_agent_by_id`, `perform_level_change`, `perform_level_warp`.

- **`GameFlow`** (`game/globals/game_flow/game_flow.gd`)
  - Owns: menu/pause/loading state machine (BOOT/MENU/LOADING/IN_GAME/PAUSED).
  - Owns: the loading transition pipeline (fade out → swap scene/load/continue → fade in).
  - Uses: `UIManager` screens + `LoadingScreen` overlay.

- **`FlowStateManager`** (`game/globals/game_flow/flow_state_manager.gd`)
  - Owns: the *world-mode* state (orthogonal to GameFlow): `Enums.FlowState.{RUNNING,DIALOGUE,CUTSCENE}`.
  - Owns: input locking, controller locking, HUD visibility, vignette, pause reasons for `TimeManager`.

- **`SceneLoader`** (`game/globals/game_flow/scene_loader.gd`)
  - Owns: mapping `Enums.Levels` → level scene path.
  - Owns: “bind active level when ready” (tile layers may require a frame after scene change).
  - Owns: a loading-depth counter and the “loading pause reason”.

### Save system

- **`SaveManager`** (`game/globals/game_flow/save/save_manager.gd`)
  - Owns: session/slot directory management and file IO.
  - Files (session):
    - `user://sessions/current/game.tres` → `GameSave`
    - `user://sessions/current/agents.tres` → `AgentsSave`
    - `user://sessions/current/dialogue.tres` → `DialogueSave`
    - `user://sessions/current/levels/<level_id>.tres` → `LevelSave`
  - Files (slot): `user://saves/<slot>/...` (copied from session).
  - Important: uses `ResourceLoader.CACHE_MODE_IGNORE` when reading session/slot resources to avoid stale caching.

- **Capture/Hydrate**
  - Capture: `game/globals/game_flow/capture/*` (`LevelCapture`, `EntityCapture`, `TerrainCapture`).
  - Hydrate: `game/globals/game_flow/hydrate/*` (`LevelHydrator`, `EntityHydrator`, `TerrainHydrator`).

### World/grid

- **`WorldGrid`** (`game/globals/grid/world_grid.gd`)
  - A facade over:
    - `TileMapManager` (tilemap binding/access)
    - `OccupancyGrid` (runtime occupancy + interactable queries)
    - `TerrainState` (persisted terrain deltas + day tick rules)
  - Owns: binding/unbinding to `LevelRoot`, buffering occupancy registration before bind.

### Time

- **`TimeManager`** (`game/globals/time/time_manager.gd`)
  - Owns: game clock with minute-level ticks and pause reasons.
  - Emits: `time_changed(day_index, minute_of_day, day_progress)`.
  - Emits (via EventBus): `EventBus.day_started(day_index)` on day advance.

### Agents/NPCs

- **`AgentBrain`** (`game/globals/agent/agent_brain.gd`)
  - Owns: agent simulation tick (driven by `TimeManager.time_changed`).
  - Owns: online/offline schedule resolution + order computation.
  - Owns: persistence of `AgentsSave` when agent records mutate.
  - Contains:
    - `AgentRegistry` (authoritative `AgentRecord` store)
    - `AgentSpawner` (materializes records into runtime nodes for the active level)

- **`AgentRegistry`** (`game/globals/agent/agent_registry.gd`)
  - Owns: `AgentRecord` store.
  - Contract: `commit_travel_by_id()` is the *only* function that changes `AgentRecord.current_level_id`.
  - Runtime capture can be temporarily disabled (during loading/cutscenes) to avoid corrupt writes.

### Dialogue/cutscenes

- **`DialogueManager`** (`game/globals/dialogue/dialogue_manager.gd`)
  - Owns: application-facing dialogue/cutscene orchestration.
  - Owns: switching `FlowStateManager` state, and save capture/hydration for dialogue variables.
  - Uses:
    - `DialogicFacade` (all direct interaction with Dialogic singleton)
    - `DialogueStateSnapshotter` (agent snapshot/restore for cutscenes)

- **`DialogicFacade`** (`game/globals/dialogue/dialogic_facade.gd`)
  - Owns: low-level timeline start/stop/clear and variable access.
  - Encapsulates: Dialogic singleton access at `/root/Dialogic`.

- **`DialogueStateSnapshotter`** (`game/globals/dialogue/dialogue_state_snapshotter.gd`)
  - Owns: best-effort snapshots of pre-cutscene agent records.
  - Important behavior: it captures snapshots broadly (player + spawned agents), but **restoration is explicit** (timeline events choose who gets restored).

### UI, debug, utilities

- **`UIManager`** (`game/ui/ui_manager.gd`)
  - Owns: global UI overlays that survive scene changes (menus, HUD, loading, vignette).
  - Owns: loading overlay reference counting to prevent flicker.

- **`GameConsole`** (`debug/console/game_console.tscn`)
  - Debug-only in-game console with command modules.

- **`DebugGrid`** (`debug/grid/debug_grid.tscn`)
  - Debug-only overlay for grid/agents/markers.

- **`EventBus`** (`game/globals/utils/event_bus.gd`)
  - Owns: cross-system signal API (time, terrain, travel, dialogue/cutscene requests, etc.).

## Flow states (how gameplay is paused/locked)

There are two orthogonal layers:

1) **Menu/pause/loading**: `GameFlow.State`
- `MENU`: main menu visible, not in gameplay.
- `LOADING`: transitions (fade/scene change/load).
- `IN_GAME`: gameplay running (subject to world-mode state).
- `PAUSED`: pause menu (SceneTree paused).

2) **World-mode**: `Enums.FlowState` (managed by `FlowStateManager`)
- `RUNNING`: normal gameplay.
- `DIALOGUE`: SceneTree paused; dialogue UI runs in `PROCESS_MODE_ALWAYS`.
- `CUTSCENE`: SceneTree runs, but player input + NPC controllers are disabled; cutscene events drive motion.

Rule of thumb:
- **GameFlow** decides “are we in menus/loading/paused?”
- **FlowStateManager** decides “what is gameplay allowed to do right now?”

## Save model (what gets saved)

The save system splits data by responsibility:

- **`GameSave`**: global clock + which level to load on continue.
- **`AgentsSave`**: player + NPC `AgentRecord`s (cross-level persistence).
- **`LevelSave`**: per-level terrain deltas + entity snapshots owned by that level.
- **`DialogueSave`**: Dialogic variables (branching state, completion flags, daily flags).

Persistence ownership:
- `Runtime.autosave_session()` is the main “write checkpoint” (only allowed in RUNNING mode).
- `AgentBrain` may persist agents during simulation ticks (but is gated during loading).
- `DialogueManager` persists dialogue state via `Runtime.autosave_session()` after timelines end (keeps “no-save window” minimal).
