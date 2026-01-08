# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

## Current cycle (finish first)

- [ ] **[NICE] Relationships**: create `RelathionshipManager` and system
1) Create relathioships system with common API for increasing and querying
2) Bootstrap with one dict per NPC, use animated sprite
3) Use hearth icon for base interface
4) Make so quests can reward relathioship progress (and wire it in the quest UI and rewards UI etc...)

- [ ] **[MUST] Quest and money reward**: Change so Frieren quest awards the player money, and we have the watering can from default
1) Add money symbol to inventory and shop UI
2) Add money animation for the grant item reward
3) Change so quest diary and notification can play sprite or animation, so we actually play the bot animation (cool no?)

- [ ] **[NICE] Regression simulation**: Expand enviroment to regress soil/dirt tiles into grass eventually by a determistic chance that increases with day passed

- [ ] **[MUST] Test in editor**: Create better tooling for testing in editor (opening level directly, creating good test levels for common patterns etc...)
1) Also do a hard pass on the tools for creating the points and spawn
2) Hard pass on the map tool and interaction with the points tool so we make sure it does not have any bugs

- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)
- [ ] **[NICE] Context-sensitive prompt text**
1) Add this via component, it should be like ballon or popup (so we can have the proper layout)
2) It will accept values like Icons (for keys) text and etc
3) We need to make so when near shop NPC it appears F shop or something like that
4) Also wire this for use in cutscenes, so we can show emojis/reactions for players/NPCs

- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)

### Core stamina loop

- [ ] **[MUST] Energy drains per tool use** (data-driven per tool/action)
- [ ] **[MUST] Energy at/near zero affects player**
  - [ ] **[MUST] Reduce movement speed**

## Later (only once Core feel is done)

### Systems & tech debt

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
- [ ] **[NICE] NPCs**: expand to accept portrait as sprite or something so we can use in other systems
