# AgentRegistry & NPC Simulation (Online vs Offline)

This document explains the intended architecture for **NPC schedules**, **cross-level movement**, and how `AgentRegistry` fits into the system.

## The two worlds: Scene vs Save (current implementation)

- **Scene (runtime)**: only the *active* level exists as Nodes.
  - Player and any in-level NPCs exist as true Nodes here and can physically move, collide, and trigger areas.
- **Save (persistence)**:
  - `GameSave`: global meta (day, active level).
  - `LevelSave`: per-level terrain deltas (`cells`) + entity snapshots (`entities`) for level-owned entities.
  - `AgentsSave` (`user://sessions/<session>/agents.tres`): **global agent records** for Player + NPCs.

If an NPC is not a Node (because its level is unloaded), it **cannot**:
- move using physics
- collide
- enter TravelZones

So offscreen NPC movement must be **simulated as data**, not as Nodes.

## Runtime occupancy grid vs Agent records (why both exist)
Two systems coexist on purpose:

- **Agent records (`AgentRecord` / `AgentsSave`)**: persistence + orchestration
  - Works even when a level is unloaded (offline simulation updates records)
  - Drives spawn/despawn via `AgentSpawner`
  - Source of truth for “where the NPC *should* be” in global time

- **Runtime occupancy (`WorldGrid` + `GridDynamicOccupantComponent`)**: interaction/collision at runtime
  - Used for tool blocking, interaction checks, and any “is someone on this tile?” logic
  - Emits `EventBus.occupant_moved_to_cell`, which `AgentRegistry` uses to keep `last_world_pos/last_cell` fresh for spawned agents

In other words: **records** solve *persistence & cross-level simulation*, while the **grid** solves *moment-to-moment gameplay interactions*.

## AgentRegistry (current state)

`AgentRegistry` is an autoload that tracks **agents** (Player/NPC) by:
- `agent_id`, `kind`
- `current_level_id`
- `last_cell` / `last_world_pos`
- pending travel fields (`pending_level_id`, `pending_spawn_id`)

Today it is both:
- a **runtime index** (orchestration/debugging)
- the in-memory source of truth for **AgentsSave** (persisted global agent state)

### Player is not a LevelSave entity
The player is treated as an **agent** only:
- Player position/inventory/tool selection are persisted via `AgentsSave` (`AgentRecord` for `&"player"`).
- The player is intentionally **not** captured into `LevelSave.entities` anymore.

This avoids duplication/conflicts between "level entity snapshots" and "global agent records".

## Implemented direction: NPCs use a global record (Option B)

For scheduled NPCs that can move between levels while unloaded:
- Treat NPCs as **global agents** with persisted records.
- When a level loads, **spawn** NPC Nodes for agents whose `current_level_id == active_level_id`.
- When a level unloads, **despawn** those NPC Nodes.

This avoids the complexity of moving NPC entity snapshots between `LevelSave(A)` and `LevelSave(B)` at runtime.

### AgentSpawner (runtime materialization)
`AgentSpawner` is an autoload responsible for converting `AgentRegistry` records into runtime Nodes:
- **Player**: placement policy is explicit (`Enums.PlayerPlacementPolicy`):
  - Continue: record position can win
  - Travel: spawn marker can win
- **NPCs**: spawned when `rec.kind == NPC` and `rec.current_level_id == active_level_id`
  - Despawn when they don't belong to the active level anymore
  - Apply `AgentRecord` state on spawn (position + inventory/tool + custom hooks)
  - Capture `AgentRecord` state on despawn and on autosave

The goal is to keep `GameManager` focused on scene change + calling spawner sync, not managing NPC nodes directly.

## Schedules are time-based, not tick-based

To avoid “NPC schedule slows down if the level was unloaded”, drive schedules from global time.

Each schedule step should have:
- `step_started_at` (global timestamp)
- `step_duration_s` (seconds)
- `route_id` (a route in the level) or `travel_target` fields

Progress is:

\[
progress = clamp((now - step\_started\_at) / step\_duration,\ 0,\ 1)
\]

This means:
- You can spawn an NPC mid-route at the correct position (based on time).
- Offline simulation can “catch up” by comparing `now` to `step_started_at + duration`.

## Level-owned routes (waypoints / Path2D)

Routes should be authored in the **level**, not per-NPC, so multiple NPCs can share them.

Typical authoring:
- Level has `Waypoints/` container.
- Under it, routes are `Path2D` (or Marker2D chains).
- Each route has a stable `route_id` (usually node name).

### Online (level loaded)
- NPC Node follows the route smoothly (Path2D sampling / steering).
- Collisions are handled by physics and/or simple avoidance.

### Offline (level unloaded)
Do not pathfind.
- Compute progress from timestamps.
- When needed (load, day tick), resolve which schedule step is active and where the NPC should be.
- Update agent record (`current_level_id`, `last_spawn_id` or `last_cell`) accordingly.

## Travel between levels

`TravelZone` emits an event (`travel_requested`).

- **Player**: handler changes the active scene, spawns/moves player to spawn marker.
- **NPC**: handler updates the agent record (no scene change) and then `AgentSpawner` syncs so the runtime reflects travel immediately.

If an NPC “travels” while its current level is loaded, the NPC handler should also **despawn** the Node, otherwise the NPC will still be present visually.

## Debugging

You should be able to inspect `AgentRegistry` at runtime:
- list agents
- filter by level
- see pending travel and last positions

The debug console provides:
- `agents [level_id]`: prints current in-memory `AgentRegistry`
- `save_dump session`: summary of current session save files
- `save_dump slot <slot>`: summary for a slot without loading it
- `save_dump_agents session|slot <name>`: prints `AgentsSave` records
- `save_dump_levels session|slot <name>`: lists `LevelSave` ids


