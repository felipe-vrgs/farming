# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

The intent is to keep **one clear “current cycle”**, then a **tight “next cycle”** (post current), and everything else goes into **Later**.

## Current cycle (finish first)

- [ ] **[NICE] Music system (background + ambience)**: data-driven by level/time/state
  - [ ] **[NICE] Music player**: extend `game/globals/effects/sfx_manager.gd` with a dedicated music player + fade in/out + EventBus-driven music events
  - [ ] **[NICE] Fade-in/out on sleep (music)** (visual fade already exists)
  - [ ] **[NICE] Ambient world audio** (wind/birds/night crickets; time + weather driven)
  - [ ] **[NICE] Audio buses** (e.g. footsteps, ambience, music)

### Tool & Item - Hotbar & Inventory

- [ ] **[MUST] Make it so tools and items can be considered the same base object (or the item can have a tool)**
- [ ] **[MUST] Change hotbar to start as default but allow reordering and switching with inventory slots**
- [ ] **[NICE] Allow in shop to also show items in hotbar (but only sellable items - tools could not be sellable at first)**
- [ ] **[NICE] Create player animation for item carry**
- [ ] **[MUST] Seed placement obeys same rules as placeable items**
- [ ] **[NICE] Seeds placement preview**
  - [ ] **[NICE] Ghost sprite on cursor**
  - [ ] **[NICE] Green = valid, red = invalid**
  - [ ] **[NICE] Soft snap to grid when placing**
  - [ ] **[NICE] Placement “thunk” feedback** (tiny camera shake + SFX on successful place)

### NPCs schedule

- [ ] **[MUST] Change so spawn points derive from a base class world point**
- [ ] **[MUST] Change so routes is a sequence of world points**
- [ ] **[MUST] Change agent brain so it can resolve the schedule this way**
  - If the next point in a route is in another level, just teleport to that point and keep following the next point
  - Same rules apply to online behaviour
  - If for any reason NPC is supposed to be in another level it should always be spawned (But I think just changing this behaviour already fixes that)
- [ ] **[MUST] Change localizer editor so we can edit these multi level routes**
- [ ] **[NICE] Add IDLE event to schedule, where NPC can keep walking between route points in semi-random fashion**

### Core stamina loop

- [ ] **[MUST] Energy drains per tool use** (data-driven per tool/action)
- [ ] **[MUST] Energy at/near zero affects player**
  - [ ] **[MUST] Reduce movement speed**
  - [ ] **[LATER] Auto sleep when threshold is hit**
- [ ] **[LATER] Decide if harvesting consumes energy**

### QoL that makes the above feel great

- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)
- [ ] **[NICE] Interaction highlight outline** (tile/entity under cursor or in front of player)
- [ ] **[NICE] Context-sensitive prompt text** (“Water”, “Harvest”, “Talk”, “Plant”)
- [ ] **[NICE] World item pickup feedback**: pickup SFX/VFX + partial pickup feedback when inventory full
  - [ ] **[NICE] Partial pickup feedback when inventory is full** (SFX/VFX + message)
- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)

## Later (only once Core feel is done)

### Systems & tech debt

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


- [] Better VFX/SFX on:
  - Passing trought a plant (shake)
  - Hitting small rock/tree (particles)
  - Hitting big tree/rock (particles + shake) and in tree it also drop leaves
