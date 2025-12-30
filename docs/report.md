# Repository Status Report (Dec 2025)

## Executive summary

This repository is an **early pre-production / strong technical prototype** for a farming game in **Godot 4.5+ (GDScript)**. The core strength is the **foundation**: grid-based farming simulation, modular architecture (autoload singletons + event bus), and a non-trivial **save/load system** including **persistent entity reconciliation** and **offline day simulation**.

The current codebase is well-positioned to support a “cozy farming foundation + later narrative subversion,” but the next prototype scope (NPCs + branching dialogue + story flags) will require **explicit story-state persistence** and **slight hardening/extension** of the save/capture flow beyond farm-only scenes.

**Time-invested estimate (based on code maturity):** ~60–110 focused hours total (≈ 8–14 intense dev-days). The reported **10-day sprint** is consistent with this.

---

## Project snapshot

- **Engine**: Godot 4.5+
- **Language**: GDScript
- **Primary architecture**: Autoload “services” + `EventBus` for decoupling
- **Key systems present**:
  - Grid farming model/view split
  - Player + plant state machines
  - Tools + hotbar
  - Save/load (session + slots)
  - Offline simulation for unloaded levels

---

## What’s already built (high-signal)

### Architecture / codebase maturity

- **Autoloads** (`project.godot`):
  - `WorldGrid`, `TerrainState`, `OccupancyGrid`, `TileMapManager`, `TimeManager`, `EventBus`, `SaveManager`, `GameManager`, plus VFX/SFX + debug tools.
- **Decoupled event-driven patterns**:
  - `EventBus` signals for day changes, terrain changes, tool equip, etc.
- **Separation of concerns**:
  - `TerrainState` = persisted terrain deltas + simulation driver (“truth” for terrain)
  - `OccupancyGrid` = runtime-only occupancy cache (“truth” for queries in the active scene)
  - `TileMapManager` = view (“only place that writes to TileMap layers”)
- **Documentation exists and matches the code**:
  - `docs/architecture.md`, `docs/grid_system.md`, `docs/save_system.md`, `docs/code_review.md`

### Farming simulation foundation

- **Grid cell state**:
  - terrain deltas (`TerrainCellData`, `TerrainState`)
  - occupancy/entities (`CellOccupancyData`, `OccupancyGrid`)
  - facade API for gameplay (`WorldGrid`)
- **Plant growth**:
  - Growth is day-based, state-machine-driven (`entities/plants/*`).
  - Plant content is resource-driven (`PlantData`).
  - Plant atlas helper (`@tool`) improves content iteration speed.
- **Tools + interactions**:
  - Player uses a tool on a target cell → tool queries entities on that cell → calls `on_interact`.
  - This is a coherent single pipeline that can be extended to NPCs.

### Save/load (major strength for such an early project)

- **Session vs slot** save model:
  - Autosave “session” files + copy to named slots for “Save Game.”
- **Capture/hydration pipeline**:
  - `world/capture/*` produces `LevelSave` snapshots.
  - `world/hydrate/*` rebuilds terrain + entities.
- **Persistent entity reconciliation**:
  - `PersistentEntityComponent` provides stable IDs for editor-placed entities (e.g., trees), preventing duplication and enabling “destroyed in save” behavior.
- **Offline simulation**:
  - `GameManager` advances unloaded level saves on day transitions (plants grow / soil dries even when off-level).

---

## Current gaps (for a “cozy farming loop”)

This repo is strongest at “systems foundation,” but is not yet at “cozy loop complete.”

- **Harvest reward loop**:
  - Plants can be harvested (removed), but full reward handling (spawn item / inventory / economy feedback) is still in roadmap.
- **Economy/progression** (typical cozy loop drivers):
  - Shop/sell/buy, upgrades, stamina/energy, etc. are not in place yet (can be delayed for the first narrative prototype).
- **UX polish**:
  - Inventory UI screen, improved HUD/feedback, error reporting are listed in `TODO.md`.

---

## Prototype target scope (agreed direction)

### NPCs (5 total)

Goal: NPCs that **walk**, can be **talked to**, and have **persistent dialogue/story state**.

**Proposed approach (matches current architecture):**

- NPCs are **grid entities** and interactables.
- Add a `GridWalkingComponent` that:
  - Tracks current cell from position.
  - Updates `OccupancyGrid` registration when crossing into a new tile (via `WorldGrid` facade).
  - Enables tool-like targeting (player aims at a cell, NPC is an entity in that cell).

Why this makes sense:
- It aligns with your existing interaction design (`ToolData.try_use()` → cell entities → `on_interact`).
- It keeps “who is at this cell?” queries centralized in `WorldGrid` (backed by `OccupancyGrid`).

### Dialogue system

You prefer a **partner-friendly authoring tool** for iteration speed. Recommended: **Dialogic 2**.

- Reference: [`dialogic-godot/dialogic`](https://github.com/dialogic-godot/dialogic)
- Why it’s a fit:
  - Fast iteration for story/content work.
  - Strong tooling for branching dialogues and character-driven narratives.

Key integration principle:
- Treat Dialogic as the **authoring + runtime** for dialogue, but persist critical state (flags/variables) through your save system so it survives:
  - scene changes
  - save/load
  - slot switching

---

## Why save-state architecture needs “hardening” for NPC + dialogue

The current save system is robust for **grid-registered simulation entities** (plants/trees/terrain), but it lacks a few pieces needed for narrative prototypes:

### 1) Farm-only grid initialization (historical)

This was an earlier risk when grid state was farm-only. The current code initializes the grid systems for all `LevelRoot` scenes, and entity capture/hydration is scene-tree based.

For NPCs/dialogue across multiple scenes, the recommended approach is already in place:
- Grid systems initialize for all `LevelRoot` scenes.
- Entity capture/hydration uses the scene tree (`LevelRoot.get_entities_root()`).

### 2) Global story/dialogue state needs a formal home

Branching dialogue implies persistent variables:
- met NPCs
- choices taken
- “twist has started”
- quest/story flags

At the moment, the save system persists mostly:
- per-level terrain + entity snapshots
- session meta like day + active level

**Missing for narrative prototypes:** a dedicated, persisted **StoryState** (global variables/flags) that Dialogic and NPC logic can read/write.

### 3) Entity state persistence needs a single clear contract

Entity capture currently tries multiple approaches:
- `entity.get_save_state()` if present
- fallback to a `SaveComponent` if present

This works early on, but becomes error-prone as you add NPCs, dialogue triggers, and quest objects.

**Hardening goal:** standardize on **one** save interface (recommended: `SaveComponent`), so every saveable entity behaves consistently and is easy to audit.

### 4) Save versioning / migrations

You already have `LevelSave.version = 1`, which is a great start. What’s missing is **migration logic** when data shapes change (common during dialogue prototyping).

**Hardening goal:** add a migration step on load:
- if save version is old → upgrade dictionaries/fields to current format
- keep older saves from breaking while iterating on story content

### 5) Performance scaling (not urgent for the first narrative prototype)

Hydration instantiates entities in one loop (synchronous). For a big farm this can cause a noticeable stall.

This is a known TODO (“Async Hydration”). It’s not required for the initial 5-NPC prototype unless you’re already spawning a large number of runtime entities.

---

## NPC movement: “walking between points” vs true pathfinding

### Walking between points (waypoints)

NPC follows a sequence of authored points (markers) and moves directly toward them.

- **Pros**: fastest to implement, easy to author, great for prototypes.
- **Cons**: can get stuck if you introduce obstacles; doesn’t adapt if paths are blocked.

### True pathfinding (navigation)

NPC uses a navigation system (navmesh/agent) to compute a route around obstacles and follow it.

- **Pros**: robust in complex maps; NPCs rarely get stuck; adapts to obstacles.
- **Cons**: more setup and tuning; more edge cases; takes longer.

**Recommendation for the first prototype:** start with **waypoints** and graduate to navigation if/when NPCs get stuck in real playtests.

---

## Dialogic integration notes (practical plan)

Reference: [`dialogic-godot/dialogic`](https://github.com/dialogic-godot/dialogic)

The key to keeping saves stable is to treat dialogue state as **game state**, not “UI state.”

### Recommended architecture

- **StoryState (global)**:
  - A dictionary/resource stored in your `GameSave` (or separate `StorySave` file).
  - Holds “flags/variables” that drive dialogue branches and story progression.
  - Example categories:
    - `flags.met_<npc_id>`
    - `flags.twist_started`
    - `ints.affinity_<npc_id>`
    - `strings.last_dialogue_node_<npc_id>`

- **NpcState (per NPC)**:
  - Stored via `SaveComponent` on each NPC (position/cell, schedule index, etc.).
  - NPC interacts with StoryState when talking (set flags, unlock nodes, etc.).

### Why this matches your save system

- Slot/session saves already exist.
- Persistent authored entities already have stable IDs.
- Adding a global StoryState makes dialogue branches survive:
  - scene transitions (`island` ↔ `npc_house`)
  - save/load
  - slot switching

---

## Feasibility: prototype with 5 NPCs + branching dialogue + story intro

This scope is feasible for a solo developer, but it is not “content only.” It requires two foundational systems plus persistence integration.

### Time estimate (solo dev, realistic)

**Target: a presentable vertical-slice prototype** (walk around, meet 5 NPCs, branching conversations, persistent choices, intro + twist setup)

- **NPC foundation** (NPC entity, grid walking, interaction hook, basic schedule/idle): **1.5–3.5 weeks**
- **Dialogue system integration (Dialogic)** (UI flow, triggers, variable plumbing): **1.5–3.5 weeks**
- **Persistence hardening for narrative** (StoryState save, non-farm level support, save contract cleanup): **1.5–4.0 weeks**
- **Polish + bug fixing + iteration tax**: **1.0–3.0 weeks**

**Total estimate:** **~6–12 weeks**.

If NPC movement is waypoint-based and dialogue branching is kept moderate, expect closer to **6–8 weeks**.

---

## Key risks & mitigations

- **Save/capture source-of-truth risk (highest)**:
  - Risk: NPCs/dialogue objects aren’t captured reliably if they are not saved via `SaveComponent`.
  - Mitigation: standardize on `SaveComponent` and ensure NPCs live under `LevelRoot` save roots.

- **Scope creep risk**:
  - Risk: “5 NPCs + dialogue” can explode into relationship sim, gifts, quests, cutscenes, etc.
  - Mitigation: define strict prototype rules (simple schedules, limited branching depth, minimal UI).

- **Tool/interaction scaling risk**:
  - Risk: adding more interactables via `on_interact` + action kinds can become brittle.
  - Mitigation: adopt your TODO: componentized interaction (e.g., `InteractableComponent`, `TalkableComponent`, etc.).

- **Iteration friction risk**:
  - Risk: without migrations, old saves break frequently while story/dialogue formats evolve.
  - Mitigation: add save versioning + migrations early (even minimal ones).

---

## Recommended next steps (next 2–3 weeks)

### 1) Decide the persistence approach for non-farm scenes

This is already addressed: grid systems initialize for all `LevelRoot` scenes and capture is scene-tree based.

### 2) Add “StoryState” persistence

- Create a simple global state container saved alongside `GameSave`.
- Integrate Dialogic variables/flags with StoryState.

### 3) Add NPC entity + GridWalkingComponent (prototype-grade)

- NPC is a grid entity (`GridOccupantComponent`).
- Updates its cell registration when crossing tile boundaries.
- Implements `on_interact` for “talk.”

### 4) Integrate Dialogic for branching dialogue

- Trigger dialogues from NPC `on_interact`.
- Read/write StoryState variables to unlock branches and record choices.

---

## Conclusion

This repo already contains a **strong farming foundation** and unusually mature persistence/architecture for its age. The next prototype scope (5 NPCs + branching dialogue + story intro) is feasible, but it requires:

- a clear, persisted **StoryState**
- a small refactor/extension so saving works across **all relevant scenes**, not only farm levels
- an NPC movement/interaction system that fits the existing grid + tool interaction pipeline

With tight scope control, a presentable prototype is realistic in **6–12 weeks** for a solo developer.


