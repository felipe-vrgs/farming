# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Follow-ups (prioritized)

- [ ] **P0 - Dialogue persistence completeness**: persist `DialogueSave.completed_timelines` (mark finished timelines in `DialogueManager` on timeline end, and load it back on hydrate). Right now only Dialogic variables are captured.
- [ ] **P1 - Cleanups**: remove or use `DialogueManager._CUTSCENE_RESTORE_FADE_SEC` (currently unused) and do a quick pass for any other dead constants left from the cutscene iteration.
- [ ] **P1 - Transition speed (Dialogue ↔ Cutscene ↔ Gameplay)**: reduce/remove stacked fades (blackout + vignette), prewarm UI overlays if needed, and avoid unnecessary SceneTree pause/unpause when switching states.
- [ ] **P2 - Dialogic fork risk**: you patched `addons/dialogic/Core/DialogicUtil.gd` to support a root `extensions_folder/index.gd`. Track this as intentional tech debt (upstream updates may overwrite it).

## Gameplay

- [ ] **Quests**: Create `QuestManager` and quest system
- [ ] **Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
- [ ] **Harvest rewards**: hook `Plant` harvest to spawn items / add to inventory
- [ ] **Objects/tools**: rocks + pickaxe, etc.
- [ ] **Hand interaction polish**: animation/behavior/icon flow
- [ ] **World item pickup feedback**: play pickup SFX/VFX when `WorldItem` is collected (and some feedback for partial pickup when inventory is full)

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

## Performance

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
