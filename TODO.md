# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Now (next session)

### Routes as resources (v2)

- [x] **RouteResource (MVP)**: store waypoint/path data as `.tres` resources (decouple from level scenes)
- [x] **Bake tool (MVP)**: one-click “bake routes from current level scene → RouteResources”
- [x] **Schedule steps reference RouteResources**
- [x] **Offline route position (v2)**: given RouteResource + time, compute approximate `AgentRecord.last_world_pos`

### Travel debugging

- [x] **Debug console**: `npc_travel <id> <level> <spawn>` (uses unified travel API)
- [x] **Debug console**: `npc_travel_intent <id>` (print pending + deadline)

### Debug tools / developer UX

- [x] **GameConsole refactor**: split commands into modules, improve help/usage, and add command grouping/search (keep backward-compatible commands)
- [x] **Debug minimap overlay**:
  - [x] Render active-level entities (player + spawned NPCs + key markers)
  - [x] Render offline agents from `AgentRegistry` (even if their level is unloaded)
  - [ ] Optional: filter by level id + toggle categories (agents, spawn markers, travel zones)

### Time + dialogue policy

- [ ] **Dialogue pauses world clock** (default policy)
- [ ] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [ ] **Agent lock/hold state**:
  - [ ] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [ ] Other NPCs → `HOLD` (freeze controller)

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
