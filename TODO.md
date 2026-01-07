# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

The intent is to keep **one clear “current cycle”**, then a **tight “next cycle”** (post current), and everything else goes into **Later**.

## Current cycle (finish first)

- [ ] **[MUST] Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
  - [ ] **[MUST] Shop UI**: vendor panel + player inventory panel + money display
  - [ ] **[MUST] Transaction rules**: stack limits, partial buys/sells, “not enough money”, “inventory full”
  - [ ] **[MUST] Save/Load**: money + vendor inventory (if applicable) + last selected vendor state (optional)

- [ ] **[NICE] Music system (background + ambience)**: data-driven by level/time/state
  - [ ] **[NICE] Music player**: extend `game/globals/effects/sfx_manager.gd` with a dedicated music player + fade in/out + EventBus-driven music events
  - [ ] **[NICE] Fade-in/out on sleep (music)** (visual fade already exists)
  - [ ] **[NICE] Ambient world audio** (wind/birds/night crickets; time + weather driven)
  - [ ] **[NICE] Audio buses** (e.g. footsteps, ambience, music)

## Next cycle (after Shop + Music) — “Core feel” milestone

### Farming interactions (Stardew “feel”)

- [ ] **[MUST] Seed placement obeys same rules as placeable items**
- [ ] **[NICE] Seeds placement preview**
  - [ ] **[NICE] Ghost sprite on cursor**
  - [ ] **[NICE] Green = valid, red = invalid**
  - [ ] **[NICE] Soft snap to grid when placing**
  - [ ] **[NICE] Placement “thunk” feedback** (tiny camera shake + SFX on successful place)

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

### Systems & tech debt

- [ ] **[NICE] Quests**: create `QuestManager` and quest system
- [ ] **[LATER] Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] **[LATER] Async hydration**: hydrate entities in chunks to avoid frame spikes (performance)
- [ ] **[LATER] Footstep SFX by surface** (dirt/wood/grass/water edge)

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
