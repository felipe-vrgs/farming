# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

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
