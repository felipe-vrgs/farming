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
- [ ] **State machine**: improve NPC with a state machine decoupling
- [ ] **Schedule model**: steps include `step_started_at` + `step_duration_s` + target (`route_id` or travel target)
- [ ] **Schedule resolver**: given global time → determine active step + progress
- [ ] **Offline simulation**: when a level is unloaded, update `AgentRecord` (`current_level_id`, `last_world_pos`, `last_spawn_id`)
- [ ] **Debug commands for iteration**:
  - [x] spawn NPC from record / list NPCs
  - [ ] force travel for NPC id
  - [ ] force schedule step / force time

### Time + dialogue policy

- [ ] **TimeManager pause reasons**: `pause(reason)` / `resume(reason)` + `is_paused()` (support multiple reasons)
- [ ] **Dialogue pauses world clock** (default policy)
- [ ] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [ ] **Agent lock/hold state**:
  - [ ] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [ ] Other NPCs → `HOLD` (freeze controller)

## Next

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
- [ ] **Inventory screen**
- [ ] **Shop UI**: vendor panel + player inventory panel + money display
- [ ] **UI Manager**: global UI handler via EventBus (loading screens, menus, popups)
- [ ] **Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] ** Z Index**: Manage Z index properly (ground - shadows - walls - player)

## Later / only if needed

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
- [ ] **Strict initialization**: deterministic bootstrap instead of lazy `ensure_initialized` chains
