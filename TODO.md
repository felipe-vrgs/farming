# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

## Current cycle (finish first)

- [ ] **[MUST] Crete full-screen/window/borderless options and res settings**
  - Implement settings UI
  - Connect with pause menu/main menu
  - If we can also create a config for the volume of the game (and using the buses we already configured)
  - Replace player menu settings -> relathioships
- [ ] **[NICE] Quests**: create `QuestManager` and system
- [ ] **[NICE] Relationships**: create `RelathionshipManager` and system

### Core stamina loop

- [ ] **[MUST] Energy drains per tool use** (data-driven per tool/action)
- [ ] **[MUST] Energy at/near zero affects player**
  - [ ] **[MUST] Reduce movement speed**

### QoL that makes the above feel great

- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)
- [ ] **[NICE] Context-sensitive prompt text** (“Water”, “Harvest”, “Talk”, “Plant”)
- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)

## Later (only once Core feel is done)

### Systems & tech debt

- [ ] **[NICE] Make it so inventory is 16 slots, you start with 8 and unlock 8 more via an item in the shop**
- [ ] **[LATER] CutsceneDirector/CutsceneUtils**: centralize Dialogic cutscene orchestration (actor+anchor resolve, WAITING/IDLE patterns) to keep events thin
- [ ] **[LATER] Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] **[LATER] Async hydration**: hydrate entities in chunks to avoid frame spikes (performance)
- [ ] **[LATER] Footstep SFX by surface** (dirt/wood/grass/water edge)

### Time, day cycle, weather

- [ ] **[LATER] Weather effects**: rain/wind/overcast affecting lighting, ambient SFX, watering
- [ ] **[NICE] Forced sleep conditions**
  - [ ] **[NICE] After X hour** (e.g., 02:00 hard cutoff)
  - [ ] **[NICE] On full exhaustion**
- [ ] **[LATER] Forced sleep penalty decision**
  - [ ] **[LATER] Energy loss**
  - [ ] **[LATER] Money loss**
  - [ ] **[LATER] No penalty**
- [ ] **[LATER] Day start summary popup** (weather + luck + mail + today’s goals)
- [ ] **[LATER] Day end summary popup** (earnings + items shipped + skill XP)


### NPC behavior (only if needed)

- [ ] **[NICE] Add IDLE event to schedule, where NPC can keep walking between route points in semi-random fashion**
- [ ] **[LATER] Moving NPC collision behavior**
  - [ ] **[LATER] Stop when colliding with player**
  - [ ] **[LATER] Wait X seconds**
  - [ ] **[LATER] Ignore collision after timeout** (continue path even if overlapping)
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog
