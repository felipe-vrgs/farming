# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

The intent is to keep **one clear “current cycle”**, then a **tight “next cycle”** (post current), and everything else goes into **Later**.

## Current cycle (finish first)

- [ ] **[MUST] Add IDLE event to schedule, where NPC can keep walking between route points in semi-random fashion**
- [ ] **[MUST] Crete full-screen/window/borderless options and res settings**

## BUGS to fix

- [ ] **[MUST] Tab not closing the inventory**
- [ ] **[MUST] Entities are respawing after cutscene - If I clear tomatoes and tree in island and start cutscene, when I get teleported back it all respawns - Only for cutscenes it seems**
- [ ] **[MUST] Sound louder after sleep**
- [ ] **[MUST] NPC schedule not properly working on days and days gameplay**
- [ ] **[MUST] Schedule editor - Better way of showing the file selected for ROUTE**

### Core stamina loop

- [ ] **[MUST] Energy drains per tool use** (data-driven per tool/action)
- [ ] **[MUST] Energy at/near zero affects player**
  - [ ] **[MUST] Reduce movement speed**
  - [ ] **[LATER] Auto sleep when threshold is hit**
- [ ] **[LATER] Decide if harvesting consumes energy**

### QoL that makes the above feel great

- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)
- [ ] **[NICE] Context-sensitive prompt text** (“Water”, “Harvest”, “Talk”, “Plant”)
- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)

## Later (only once Core feel is done)

### Systems & tech debt

- [ ] **[NICE] Make it so inventory is 16 slots, you start with 8 and unlock 8 more via an item in the shop**
- [ ] **[NICE] Quests**: create `QuestManager` and quest system
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

- [ ] **[NICE] Idle NPCs collide with player**
- [ ] **[LATER] Idle NPCs do not move when pushed**
- [ ] **[LATER] Moving NPC collision behavior**
  - [ ] **[LATER] Stop when colliding with player**
  - [ ] **[LATER] Wait X seconds**
  - [ ] **[LATER] Ignore collision after timeout** (continue path even if overlapping)
- [ ] **[LATER] Prevent teleport/snap-back when collision resolves**
- [ ] **[LATER] Ensure collision-ignore is temporary and resets**
- [ ] **[LATER] Verify hitbox matches visual sprite**
- [ ] **[LATER] Separate idle mask from movement mask**
- [ ] **[LATER] Update idle mask logic**
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog
