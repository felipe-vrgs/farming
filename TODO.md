# Farming Game - Roadmap / TODO

## Current milestone status (done)
- [x] **Global Agents**: `AgentRegistry` + `AgentsSave` (player + NPC records)
- [x] **Runtime materialization**: `AgentSpawner` spawns/despawns agents for active level (`sync_all`)
- [x] **Save debugging**: `GameConsole` commands to dump session/slot save summaries + agents

## Now (next 1–2 sessions)
### NPC walking simulator (MVP)
- [ ] **NPC base scene**: visuals, collisions, movement controller, and `GridDynamicOccupantComponent` for occupancy + `occupant_moved_to_cell`
- [ ] **Routes in level**: author `Path2D` / waypoint routes with stable `route_id`
- [ ] **Online movement**: follow a route smoothly while the level is loaded (no schedule yet)
- [ ] **Schedule model**: steps include `step_started_at` + `duration` + target (`route_id` or travel target)
- [ ] **Schedule resolver**: given global time → determine active step + progress
- [ ] **Offline simulation**: when level is unloaded, update `AgentRecord` (`current_level_id`, `last_world_pos`, `last_spawn_id`)
- [ ] **Debug commands for iteration**:
  - [ ] spawn NPC from record / list NPCs
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
- [ ] **Pause menu**: proper pause UI + state

### Interaction refactor
- [ ] **Componentized interactions** (remove duck-typing from `ToolData`)
  - [ ] Create `InteractableComponent` base
  - [ ] Implement interaction components (`DamageOnInteract`, `LootOnDeath`, `Waterable`, etc.)

## UI & UX
- [ ] **HUD/Hotbar**: improve visuals (use a proper UI pack)
- [ ] **Inventory screen**
- [ ] **Shop UI**: vendor panel + player inventory panel + money display
- [ ] **UI Manager**: global UI handler via EventBus (loading screens, menus, popups)
- [ ] **Error reporting**: user-facing feedback for critical failures (save/load/etc)

## Later / only if needed
- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
- [ ] **Strict initialization**: deterministic bootstrap instead of lazy `ensure_initialized` chains
