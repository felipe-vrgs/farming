# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Dialogue policy

- [ ] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [ ] **Dialogic baseline wiring (end-to-end)**:
  - [x] Confirm addon is enabled + `Dialogic` autoload exists (already in `project.godot`)
  - [ ] Confirm our `DialogicIntegrator` works end-to-end: interact → `EventBus.talk_requested` → timeline starts → timeline ends → world unlocks
  - [ ] Decide canonical timeline id convention (prefer explicit `dialogue_id`, fallback to NPC id/name)
  - [ ] Create 1 real timeline + 1 NPC talk interaction as a “golden path” example
- [ ] **Agent lock/hold state**:
  - [ ] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [ ] Other NPCs → `HOLD` (freeze controller)
  - [ ] Decide whether this is a distinct runtime/game_flow state (e.g. `DIALOGUE`) vs just `TimeManager.pause("dialogue")`
  - [ ] Ensure player tool/interaction input is disabled while dialogue is active (not just movement)
- [ ] **Dialogic state & save**:
  - [ ] Decide which Dialogic variables need to be persisted into our save/session model (if any)
  - [ ] Decide whether dialogue progression is per-save-slot, per-session, or global

## Gameplay

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

## Perfomance

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
