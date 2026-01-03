# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Gameplay

- [ ] **Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
    - [ ] **Inventory screen**
    - [ ] **Shop UI**: vendor panel + player inventory panel + money display
- [ ] **Harvest rewards**: hook `Plant` harvest to spawn items / add to inventory
- [ ] **Objects/tools**: rocks + pickaxe, etc.
- [ ] **Hand interaction polish**: animation/behavior/icon flow
- [ ] **World item pickup feedback**: play pickup SFX/VFX when `WorldItem` is collected (and some feedback for partial pickup when inventory is full)
- [ ] **Quests**: Create `QuestManager` and quest system

## Audio

- [ ] **Music**: add background music system (data-driven by level/time/state)
    - [ ] **Music player**: extend `globals/effects/sfx_manager.gd` with a single dedicated music player + fade in/out + EventBus-driven music events
- [ ] **Audio buses**: Like for NPC footsteps or other special effects that we might want

## Minor stuff

- [ ] **HUD/Hotbar**: improve visuals (use a proper UI pack)
- [ ] **Z Index**: Manage Z index properly (ground - shadows - walls - player)
- [ ] **Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes -- PERFOMANCE UPGRADE
