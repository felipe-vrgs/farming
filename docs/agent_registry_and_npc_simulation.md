# AgentRegistry & NPC Simulation (Online vs Offline)

This document explains the architecture for **global agents** (player + NPCs), **cross-level movement**, and how “online” (active scene) vs “offline” (unloaded scene) simulation works.

## Related docs

- [Architecture Overview](architecture.md)
- [Save System](save_system.md)

## The two worlds: Scene vs Save

- **Scene (runtime)**: only the *active* level exists as Nodes.
  - Player and in-level NPCs exist as Nodes and can move, collide, and enter `TravelZone`s.
- **Save (persistence)**:
  - `GameSave`: global meta (day, active level).
  - `LevelSave`: per-level terrain/entity snapshots for level-owned entities.
  - `AgentsSave`: **global agent records** for player + NPCs (`AgentRecord`).

If an NPC is not a Node (because its level is unloaded), it **cannot** move using physics or trigger portals. So offscreen movement must be simulated as **data**, not nodes.

## Runtime occupancy grid vs Agent records

Two systems coexist on purpose:

- **Agent records (`AgentRecord` / `AgentsSave`)**: persistence + orchestration
  - Works even when a level is unloaded (offline simulation updates records).
  - Drives spawn/despawn via `AgentSpawner`.
- **Runtime occupancy (`WorldGrid` + `GridDynamicOccupantComponent`)**: interaction/collision at runtime
  - Emits `EventBus.occupant_moved_to_cell`, which `AgentRegistry` uses to keep record positions fresh.

## AgentRegistry / AgentSpawner

- `AgentRegistry` is an autoload that stores `AgentRecord`s in memory and saves them to `AgentsSave`.
- `AgentSpawner` materializes NPC nodes for the active level:
  - spawn when `rec.kind == NPC` and `rec.current_level_id == active_level_id`
  - despawn otherwise

## Schedules (v1)

Schedules are keyed by **in-game minute-of-day**:

- `NpcScheduleStep.start_minute_of_day` (0..1439)
- `NpcScheduleStep.duration_minutes`
- payload:
  - ROUTE: `level_id`, `route_res`, `loop_route`
  - TRAVEL: `target_level_id`, `target_spawn_id`, optional `exit_route_res`

Resolution happens via:
- `NpcScheduleResolver.resolve(schedule, minute_of_day)`
- driven by `TimeManager.time_changed`

## Online vs offline ownership

- **Online (NPC spawned)**: `NpcScheduleResolver` component drives state changes and motion.
- **Offline (NPC not spawned)**: `OfflineAgentSimulation` updates `AgentRecord`s on `TimeManager.time_changed`.

Offline also computes approximate route positions for ROUTE steps by sampling `RouteResource`
and storing the result in `AgentRecord.last_world_pos`.

## Travel: portal-first + TravelIntent deadline

`TravelZone` emits `EventBus.travel_requested(agent, target_level_id, target_spawn_id)` for **both** Player and NPCs.

- **Player**: handler loads the destination scene and spawns/moves the player to a spawn marker.
- **NPC**: handler commits travel in `AgentRecord` and then `AgentSpawner` syncs.

### TravelIntent (pending travel)

To support “walk to portal when online, but still be strict if blocked”, `AgentRecord` has:

- `pending_level_id`, `pending_spawn_id`
- `pending_expires_absolute_minute` (deadline)

When a schedule TRAVEL step has `exit_route_res != null`:
- online: NPC walks the exit route (should end inside the portal area)
- the TravelZone commit is preferred (looks natural)
- if blocked and the deadline passes, `AgentRegistry` forces commit at the deadline

Offline:
- if `exit_route_res != null`, we queue the intent and commit at deadline (so NPC doesn’t “instantly follow” the player across a manual level change)
- if `exit_route_res == null`, we commit immediately (teleport-style)

