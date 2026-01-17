# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

## Current cycle (finish first)

- [ ] **[MUST] Content**:
  - More rocks and trees, add tier min for damage in variants

- [ ] Backpack upgrade
- [ ] Drop items/Chests/More slots to the player

- [ ] **[NICE] Map Tab/System**
  - Map UI should use **external PNG map pages** (player-facing), not “render real levels”
  - MVP: show **player dot** on the correct map page
    - Store per-level mapping:
      - `map_page_id` (which PNG/page)
      - `level_bounds` (min/max in level-local coords, or equivalent normalize inputs)
      - `rect_on_map_px` (x,y,w,h in PNG pixel space)
    - Dot placement:
      - \(u = (px - minx) / (maxx - minx)\), \(v = (py - miny) / (maxy - miny)\)
      - `dot = rect.pos + Vector2(u * rect.size.x, v * rect.size.y)`
  - Follow-ups (later): POI markers, quest pins, fog-of-war reveal, clickable map links between pages

- [ ] **[NICE] Regression simulation**: Expand enviroment to regress soil/dirt tiles into grass eventually by a determistic chance that increases with day passed

- [ ] **[NICE] Eating items**: Restore energy and such, press E to consume while in hand

### Systems & tech debt

- [ ] **[MUST] Test in editor**: Create better tooling for testing in editor (creating good test levels for common patterns etc...)
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
