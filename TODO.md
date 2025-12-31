# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Done (foundation)

- [x] **Global Agents**: `AgentRegistry` + `AgentsSave` (player + NPC records)
- [x] **Runtime materialization**: `AgentSpawner` spawns/despawns agents for the active level (`sync_all`)
- [x] **Save debugging**: `GameConsole` commands to dump session/slot save summaries + agents
- [x] **Session vs slot model**: session autosave under `user://sessions/current/`, slots under `user://saves/<slot>/`

## Now (next 1–2 sessions)

### NPC walking simulator (MVP)

- [x] **NPC runtime entity**: visuals, collisions, movement controller, and `GridDynamicOccupantComponent` for occupancy + `EventBus.occupant_moved_to_cell`
- [x] **NPC config + first spawn**: `NpcConfig` resources + SpawnMarker (`SpawnId`) seeding into `AgentRegistry` + `AgentSpawner` materialization
- [x] **Routes in level**: author `Path2D` / waypoint routes with stable `route_id`
- [x] **Online movement**: follow a route smoothly while the level is loaded (no schedule yet)
- [x] **State machine**: improve NPC with a state machine decoupling
- [x] **Route blocking**: NPC stops cleanly when player blocks route (`RouteBlocked` state + non-physical player blocking)
- [x] **Multi-level NPC travel (MVP)**: NPCs can traverse `TravelZone` portals and correctly update `AgentRegistry` so `AgentSpawner` respawns them in the destination level (no forced scene load)
- [x] **Schedule model (v1)**: step list keyed by in-game clock (`minute_of_day` / `absolute_minute`) + target (`route_id` or travel target)
- [x] **Schedule resolver (v1)**: given clock → determine active step + progress
- [x] **Offline simulation (v1)**:
  - [x] **World (LevelSave)**: day tick for unloaded levels (`OfflineSimulation.compute_offline_day_for_level_save`)
  - [x] **Agents (NPC schedules)**: minute tick for unloaded NPCs (`OfflineAgentSimulation.simulate_minute` via `AgentRegistry`)
- [ ] **Debug commands for iteration**:
  - [x] spawn NPC from record / list NPCs
  - [ ] force travel for NPC id (in addition to TravelZone portals)
  - [ ] force schedule step / force time

### Time + dialogue policy

- [x] **Game clock proxy**: `TimeManager` exposes minute-of-day/hour/minute + stable `day_progress` + `pause(reason)` / `resume(reason)` + signals for schedules
- [ ] **Dialogue pauses world clock** (default policy)
- [ ] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [ ] **Agent lock/hold state**:
  - [ ] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [ ] Other NPCs → `HOLD` (freeze controller)

## Next

### Travel refactor (v2)

- [ ] **Unify travel intent**: one API for “request travel” (Player loads scene; NPC commits record) and one place to handle side effects (save, spawn sync, despawn)
- [ ] **Online travel polish**:
  - [ ] Optional “travel preparation” state (walk exit route / walk to marker then commit)
  - [ ] Ensure schedule TRAVEL does not feel abrupt when NPC is loaded
- [ ] **Travel debugging**: `npc_travel <id> <level> <spawn>` + logs / overlay

### Routes as resources (v2)

- [ ] **RouteResource**: store waypoint/path data as `.tres` resources (decouple from level scenes)
- [ ] **Schedule steps reference resources** (replace RouteIds enum usage over time)
- [ ] **Editor tooling**: author/bake routes to resources, then pick them from schedule UI

### Gameplay

- [ ] **Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
- [ ] **Harvest rewards**: hook `Plant` harvest to spawn items / add to inventory
- [ ] **Objects/tools**: rocks + pickaxe, etc.
- [ ] **Hand interaction polish**: animation/behavior/icon flow
- [ ] **Pause menu**: proper pause UI + state (separate from debug console pause)

### Interaction refactor

- [ ] **Componentized interactions** (reduce duck-typing / tool-specific checks)
  - [ ] Create `InteractableComponent` base
  - [ ] Implement interaction components (`DamageOnInteract`, `LootOnDeath`, `Waterable`, etc.)

## UI & UX

- [ ] **HUD/Hotbar**: improve visuals (use a proper UI pack)
- [ ] **Clock**: Clock UI
- [ ] **Inventory screen**
- [ ] **Shop UI**: vendor panel + player inventory panel + money display
- [ ] **UI Manager**: global UI handler via EventBus (loading screens, menus, popups)
- [ ] **Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] ** Z Index**: Manage Z index properly (ground - shadows - walls - player)

## Later / only if needed

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
- [ ] **Strict initialization**: deterministic bootstrap instead of lazy `ensure_initialized` chains
