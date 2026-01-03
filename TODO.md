# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Dialogue policy

- [x] **Dialogue system integration**: use Dialogic 2 ([docs](https://docs.dialogic.pro/))
- [x] **Dialogic baseline wiring (end-to-end)**:
  - [x] Confirm addon is enabled + `Dialogic` autoload exists (already in `project.godot`)
  - [x] Confirm our `DialogueManager` works end-to-end: interact → `EventBus.dialogue_start_requested` → timeline starts → timeline ends → world unlocks
  - [x] Timeline ID convention: `npcs/{npc_id}/{dialogue_id}` (e.g., `npcs/frieren/greeting`)
  - [x] Create golden path example: Frieren NPC with `greeting.dtl` timeline
- [x] **Dialogic state & save**:
  - [x] `DialogueSave` model captures `Dialogic` variable dictionary
  - [x] Integrated into `SaveManager` and `GameRuntime` autosave/load
  - [x] Daily flags (ending in `_today`) reset on `day_started`
- [x] **Agent lock/hold state**:
  - [x] NPC in dialogue → `DIALOGUE_LOCK` (freeze controller)
  - [x] Other NPCs → `HOLD` (freeze controller)
  - [x] Ensure player tool/interaction input is disabled while dialogue is active (not just movement)
- [ ] **Timeline organization** (for scalability):
  - [ ] `{npc}/idle.dtl` — daily chit-chat with conditionals for variety
  - [ ] `{npc}/quests/{quest_id}.dtl` — quest-specific dialogue (triggered by QuestManager)
  - [ ] `{npc}/events/{event_id}.dtl` — heart events, special moments
  - [ ] `cutscenes/{scene_id}.dtl` — game flow cutscenes
- [x] **Architecture improvements**:
  - [x] Rename `DialogicIntegrator` → `DialogueManager` (addon-agnostic facade)
  - [x] Add EventBus API: `dialogue_start_requested`, `cutscene_start_requested`


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

## Perfomance

- [ ] **Async hydration**: hydrate entities in chunks to avoid frame spikes
