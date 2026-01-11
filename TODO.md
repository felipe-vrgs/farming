# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

## Current cycle (finish first)


- [ ] **[MUST] Scalable animations/tools/characters**:
  - [ ] **[MUST] Create scalable character animations**:
    - Use some techinique to extract animations into pieces
    - This way we can reuse the same body for NPCs/Characters and just change the texture
    - Is this the proper way of doing a character builder later on?
    - Is this the proper way of handling NPCs?
    - How does stardew valley/fields of mistra do it?

- [ ] **[MUST] Blacksmith system**:
- Create tier for tools (Done in model)
- Create logic to change Item default icon by tool atlas + tier (Already setup fields in model and sprites)
- Make tool do more damage (axe and pickaxe basically) (Already in model, needs wiring into damage system)
- Make blacksmith screen with the upgrades and costs

- [ ] **[MUST] End of the day/Progress screen**:
- Show all quest progress
- All gathered items
- Create nice UI and such

- [ ] **[NICE] Context-sensitive prompt text**
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog
1) Add this via component, it should be like ballon or popup (so we can have the proper layout)
2) It will accept values like Icons (for keys) text and etc
3) We need to make so when near shop NPC it appears F shop or something like that
4) Also wire this for use in cutscenes, so we can show emojis/reactions for players/NPCs

- [ ] **[NICE] Map Tab**

- [ ] **[NICE] Regression simulation**: Expand enviroment to regress soil/dirt tiles into grass eventually by a determistic chance that increases with day passed

- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)

- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)

- [ ] **[MUST] Test in editor**: Create better tooling for testing in editor (opening level directly, creating good test levels for common patterns etc...)
1) Tool for testing cutscenes/dialogue easily
2) Tool for testing quests objectives/rewards easily (select quest to load, select test level and see if it works)


### Systems & tech debt

- [ ] **[LATER] CutsceneDirector/CutsceneUtils**: centralize Dialogic cutscene orchestration (actor+anchor resolve, WAITING/IDLE patterns) to keep events thin
- [ ] **[LATER] UI Refactor**: Some UI components need refactor, also better component creation and theme handling
- [ ] **[LATER] Translation**: Check how we would do translation of the game texts
- [ ] **[LATER] Async hydration**: hydrate entities in chunks to avoid frame spikes (performance)
- [ ] **[LATER] Footstep SFX by surface** (dirt/wood/grass/water edge)

### Time, day cycle, weather

- [ ] **[LATER] Weather effects**: rain/wind/overcast affecting lighting, ambient SFX, watering
- [ ] **[LATER] Day start summary popup** (weather + luck + mail + today’s goals)
- [ ] **[LATER] Day end summary popup** (earnings + items shipped + skill XP)


### NPC behavior (only if needed)

- [ ] **[LATER] Moving NPC collision behavior**
  - [ ] **[LATER] Stop when colliding with player**
  - [ ] **[LATER] Wait X seconds**
  - [ ] **[LATER] Ignore collision after timeout** (continue path even if overlapping)
