# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

## Current cycle (finish first)

- [ ] Cutscene mode letting the player move?

- [ ] Add hand quest objective (which is handing X amount of items to Y npc):
- When quest is active and we have the items (like 50 wood)
- And we interact with the NPC that is the target of the quest
- Show a quick modal with (You can complete XYZ quest, hand 50 wood to NPC?)
- If no -> Resume interaction with npc as expected from regular code
- If yes -> Do action depending on quest data, if quests has a timeline_id play timeline, and quest only completes after timeline
 - If no timeline just grant the quest reward and return to IN_GAME

- [ ] Lights system:
Add lights easily to maps
Add lights to props/prefabs? (Like postlamps, candles and such??? - Need to create them if thats the case)
Add lights directly to maps?
Make time manager control lights via group (Start making them work as day dawns and so on)
Also provide API for light control via other scripts (like night time mode for example or cutscenes)
Also big how we doing cutscenes lights? Any easy way to do it?
And can we add thunder effects? Claps of lights? Rain?

- [ ] More plants variants and seeds

- [ ] More rocks and trees, add tier min for damage in variants

- [ ] **[NICE] Map Tab/System**

- [ ] **[NICE] Context-sensitive prompt text**
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog
1) Add this via component, it should be like ballon or popup (so we can have the proper layout)
2) It will accept values like Icons (for keys) text and etc
3) We need to make so when near shop NPC it appears F shop or something like that
4) Also wire this for use in cutscenes, so we can show emojis/reactions for players/NPCs

- [ ] **[LATER] Weather effects**: rain/wind/overcast affecting lighting, ambient SFX, watering

- [ ] **[NICE] Regression simulation**: Expand enviroment to regress soil/dirt tiles into grass eventually by a determistic chance that increases with day passed

- [ ] **[NICE] Eating items**: Restore energy and such, press E to consume while in hand

### Systems & tech debt

- [ ] **[MUST] Test in editor**: Create better tooling for testing in editor (opening level directly, creating good test levels for common patterns etc...)
1) Tool for testing cutscenes/dialogue easily
2) Tool for testing quests objectives/rewards easily (select quest to load, select test level and see if it works)

- [ ] **[LATER] CutsceneDirector/CutsceneUtils**: centralize Dialogic cutscene orchestration (actor+anchor resolve, WAITING/IDLE patterns) to keep events thin

- [ ] **[LATER] Translation**: Check how we would do translation of the game texts

- [ ] **[LATER] Async hydration**: hydrate entities in chunks to avoid frame spikes (performance)

- [ ] **[LATER] Footstep SFX by surface** (dirt/wood/grass/water edge)

- [ ] **[LATER] Moving NPC collision behavior**
  - [ ] **[LATER] Stop when colliding with player**
  - [ ] **[LATER] Wait X seconds**
  - [ ] **[LATER] Ignore collision after timeout** (continue path even if overlapping)
