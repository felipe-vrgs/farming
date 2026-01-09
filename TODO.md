# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

-- ALIGN WITH LOUIS:

- Tilyng grass right besides stone

## Current cycle (finish first)

- [ ] **[NICE] Add New obstacles**:
1) Create buildings and decorations
2) Make it be data driven
3) Will basically have grid entity so it blocks tilyng
4) Needs to be a tool so we can load the data we want in the editor (could even be a dropdown)
5) Data in case for buildings is = Sprite and Collision Shape to be used by grid register
And for decorations is the same basically

- [ ] **[NICE] Context-sensitive prompt text**
1) Add this via component, it should be like ballon or popup (so we can have the proper layout)
2) It will accept values like Icons (for keys) text and etc
3) We need to make so when near shop NPC it appears F shop or something like that
4) Also wire this for use in cutscenes, so we can show emojis/reactions for players/NPCs

- [ ] **[NICE] Map Tab**

- [ ] **[NICE] Regression simulation**: Expand enviroment to regress soil/dirt tiles into grass eventually by a determistic chance that increases with day passed

- [ ] **[MUST] Test in editor**: Create better tooling for testing in editor (opening level directly, creating good test levels for common patterns etc...)
1) Also do a hard pass on the tools for creating the points and spawn
2) Hard pass on the map tool and interaction with the points tool so we make sure it does not have any bugs

- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)

- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)

### Core stamina loop

- [ ] **[MUST] Energy drains per tool use** (data-driven per tool/action)
- [ ] **[MUST] Energy at/near zero affects player**
  - [ ] **[MUST] Reduce movement speed**
- [ ] **[NICE] Forced sleep conditions**
  - [ ] **[NICE] On full exhaustion**
- [ ] **[LATER] Forced sleep penalty decision**
  - [ ] **[LATER] Energy loss**
  - [ ] **[LATER] Money loss**
  - [ ] **[LATER] No penalty** -- This is what we do for now

## Later (only once Core feel is done)

### Systems & tech debt

- [ ] **[LATER] CutsceneDirector/CutsceneUtils**: centralize Dialogic cutscene orchestration (actor+anchor resolve, WAITING/IDLE patterns) to keep events thin
- [ ] **[LATER] Async hydration**: hydrate entities in chunks to avoid frame spikes (performance)
- [ ] **[LATER] Footstep SFX by surface** (dirt/wood/grass/water edge)

### Time, day cycle, weather

- [ ] **[LATER] Weather effects**: rain/wind/overcast affecting lighting, ambient SFX, watering
- [ ] **[LATER] Day start summary popup** (weather + luck + mail + today’s goals)
- [ ] **[LATER] Day end summary popup** (earnings + items shipped + skill XP)


### NPC behavior (only if needed)

- [ ] **[NICE] Add IDLE event to schedule, where NPC can keep walking between route points in semi-random fashion**
- [ ] **[LATER] Moving NPC collision behavior**
  - [ ] **[LATER] Stop when colliding with player**
  - [ ] **[LATER] Wait X seconds**
  - [ ] **[LATER] Ignore collision after timeout** (continue path even if overlapping)
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog
- [ ] **[NICE] NPCs**: expand to accept portrait as sprite or something so we can use in other systems
