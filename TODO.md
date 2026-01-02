# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Next session focus (2026-01-01 wrap)

- [ ] **Fix/stabilize NPC Avoiding state** (`entities/npc/states/avoiding.gd`): reduce jitter/oscillation, prevent stuck loops, and make player-blocker vs physics-blocker handling consistent.
- [ ] **Wire `AgentOrder.facing_dir` into NPC facing**: apply `order.facing_dir` in idle/stop cases so schedule-facing works even when not moving (today it’s effectively unused).
- [ ] **Avoiding: skip initial player delay on enter** (`entities/npc/states/avoiding.gd`): when transitioning into Avoiding, don’t wait `_WAIT_PLAYER` before the first sidestep attempt.

## Time + dialogue policy

- [ ] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [ ] **Agent lock/hold state**:
  - [ ] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [ ] Other NPCs → `HOLD` (freeze controller)

## Gameplay

- [ ] **Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
- [ ] **Harvest rewards**: hook `Plant` harvest to spawn items / add to inventory
- [ ] **Objects/tools**: rocks + pickaxe, etc.
- [ ] **Hand interaction polish**: animation/behavior/icon flow
- [x] **Pause menu**: proper pause UI + state (separate from debug console pause)

## Audio

- [ ] **Audio buses**: Like for NPC footsteps or other special effects that we might want
- [ ] **Music**: add background music system (data-driven by level/time/state)
- [ ] **Music player**: extend `globals/effects/sfx_manager.gd` with a single dedicated music player + fade in/out + EventBus-driven music events

## UI & UX

- [ ] **HUD/Hotbar**: improve visuals (use a proper UI pack)
- [ ] **Inventory screen**
- [ ] **Shop UI**: vendor panel + player inventory panel + money display
- [x] **UI Manager**: global UI handler via EventBus (loading screens, menus, popups)
- [ ] **Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] ** Z Index**: Manage Z index properly (ground - shadows - walls - player)

## Perfomance

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
- [ ] **Strict initialization**: deterministic bootstrap instead of lazy `ensure_initialized` chains
