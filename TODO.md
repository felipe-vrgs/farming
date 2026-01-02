# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Dialogue policy

- [ ] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [ ] **Agent lock/hold state**:
  - [ ] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [ ] Other NPCs → `HOLD` (freeze controller)
  - Maybe just set the game to pause mode just like game_runtime but in a different way? Maybe its another runtime state (Dialogue?)

## Gameplay

- [ ] **Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
- [ ] **Harvest rewards**: hook `Plant` harvest to spawn items / add to inventory
- [ ] **Objects/tools**: rocks + pickaxe, etc.
- [ ] **Hand interaction polish**: animation/behavior/icon flow

## UI & UX

- [ ] **Inventory screen**
- [ ] **Shop UI**: vendor panel + player inventory panel + money display
- [ ] **HUD/Hotbar**: improve visuals (use a proper UI pack)
- [ ] ** Z Index**: Manage Z index properly (ground - shadows - walls - player)
- [ ] **Error reporting**: user-facing feedback for critical failures (save/load/etc)

## Audio

- [ ] **Audio buses**: Like for NPC footsteps or other special effects that we might want
- [ ] **Music**: add background music system (data-driven by level/time/state)
- [ ] **Music player**: extend `globals/effects/sfx_manager.gd` with a single dedicated music player + fade in/out + EventBus-driven music events

## Perfomance

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
