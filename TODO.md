# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work.

## Current cycle (finish first)

- [ ] Lights system (Stardew-like: global tint + soft local glows):
  - Prefab authoring: create `LightEmitter2D` scene (Node2D + PointLight2D) for drop-in use.
  - Placement: standardize a `Lights` node in levels; allow lights in props/prefabs (lamps/candles).
  - Time-of-day control: add `LightManager` driven by `TimeManager.time_changed` with a `night_factor`.
  - Grouping: define `lights_world`, `lights_interior`, `lights_cutscene` for bulk control.
  - Cutscene API: override stack (push/pop) to force lighting states (boost/dim/disable groups).
  - Player light: drive `Player.NightLight` via the same system (night-only by default).
  - Style polish: pick 1-2 canonical light textures and import settings for smooth falloff.

- [ ] Weather scheduling + cutscene hooks (wrap WeatherManager/Layer):
  - Cutscene/quest API now:
    - `set_raining(enabled, intensity)` (already exists; use/document).
    - `trigger_lightning(strength, with_thunder, thunder_delay)` wraps `WeatherLayer.flash_lightning()`.
    - Optional override stack: `push_weather_override(token, ...)` / `pop_weather_override(token)`.
    - Optional context override for cutscenes outside farm-only active context.
  - WeatherScheduler later: day-based randomness (min/max duration, dry streaks).
  - Persistence: store forecast/schedule state in `GameSave`.
  - Debug: keep/expand console controls (rain on/off, intensity, thunder trigger).
  - Rules: optional per-level weather rules aligned with `_is_active_context()`.

- [ ] More plants variants and seeds

- [ ] More rocks and trees, add tier min for damage in variants

- [ ] **[NICE] Map Tab/System**

- [ ] **[NICE] Context-sensitive prompt text**
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog
1) Add this via component, it should be like ballon or popup (so we can have the proper layout)
2) It will accept values like Icons (for keys) text and etc
3) We need to make so when near shop NPC it appears F shop or something like that
4) Also wire this for use in cutscenes, so we can show emojis/reactions for players/NPCs

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
