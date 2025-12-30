# AgentRegistry & NPC Simulation (Online vs Offline)

This document explains the intended architecture for **NPC schedules**, **cross-level movement**, and how `AgentRegistry` fits into the system.

## The two worlds: Scene vs Save

- **Scene (runtime)**: only the *active* level exists as Nodes.
  - NPCs and the player can be true Nodes here and can physically move, collide, and trigger areas.
- **Save (persistence)**:
  - `GameSave`: global meta (day, active level, and optionally global agent records).
  - `LevelSave`: per-level terrain deltas (`cells`) + entity snapshots (`entities`).

If an NPC is not a Node (because its level is unloaded), it **cannot**:
- move using physics
- collide
- enter TravelZones

So offscreen NPC movement must be **simulated as data**, not as Nodes.

## AgentRegistry (current state)

`AgentRegistry` is an autoload that tracks **agents** (Player/NPC) by:
- `agent_id`, `kind`
- `current_level_id`
- `last_cell` / `last_world_pos`
- pending travel fields (`pending_level_id`, `pending_spawn_id`)

Today, it is primarily a **runtime index** (good for debugging and orchestration).

## Recommended direction: NPCs use a global record (Option B)

For scheduled NPCs that can move between levels while unloaded:
- Treat NPCs as **global agents** with persisted records.
- When a level loads, **spawn** NPC Nodes for agents whose `current_level_id == active_level_id`.
- When a level unloads, **despawn** those NPC Nodes.

This avoids the complexity of moving NPC entity snapshots between `LevelSave(A)` and `LevelSave(B)` at runtime.

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
- **NPC**: handler updates the agent record (no scene change).

If an NPC “travels” while its current level is loaded, the NPC handler should also **despawn** the Node, otherwise the NPC will still be present visually.

## Debugging

You should be able to inspect `AgentRegistry` at runtime:
- list agents
- filter by level
- see pending travel and last positions

The debug console can provide commands for this (see `GameConsole`).


