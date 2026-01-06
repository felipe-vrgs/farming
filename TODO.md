# Farming - Roadmap / TODO

This file is the working backlog for gameplay + architecture work. It is intentionally opinionated toward keeping the project modular (facades + components + save capture/hydration).

## Priority
- [ ] **[MUST] Shop system (money + inventory exchange)**: buy/sell UI + transactions + persistence via `AgentRecord.money` + inventory
    - [ ] **[MUST] Shop UI**: vendor panel + player inventory panel + money display

## Audio

- [ ] **[NICE] Music**: add background music system (data-driven by level/time/state)
    - [ ] **[NICE] Music player**: extend `game/globals/effects/sfx_manager.gd` with a single dedicated music player + fade in/out + EventBus-driven music events
    - [ ] **[NICE] Fade-in/out on sleep (music)** (pairs with sleep interaction; visual fade is already implemented)
    - [ ] **[NICE] Ambient world audio** (wind, birds, night crickets; time + weather driven)
- [ ] **[NICE] Audio buses**: Like for NPC footsteps or other special effects that we might want

## Time and Day Cycle

- [ ] **[LATER] NPC schedules tick**: schedule recalculation/activation on day start and/or time slots
- [ ] **[LATER] Weather effects**: rain/wind/overcast affecting lighting, ambient SFX, watering, NPC behavior
- [ ] **[NICE] Forced sleep conditions**
    - [ ] **[NICE] After X hour** (e.g., 02:00 hard cutoff)
    - [ ] **[NICE] On full exhaustion**
- [ ] **[LATER] Forced sleep penalty decision**
    - [ ] **[LATER] Energy loss**
    - [ ] **[LATER] Money loss**
    - [ ] **[LATER] No penalty**
- [ ] **[LATER] Day start summary popup** (weather + luck + mail + today’s goals)
- [ ] **[LATER] Day end summary popup** (earnings + items shipped + skill XP)

## Farming and Tiles (Stardew Feel)

- [ ] **[NICE] Seeds use placement preview**
    - [ ] **[NICE] Ghost sprite on cursor**
    - [ ] **[NICE] Green = valid, red = invalid**
- [ ] **[MUST] Seed placement obeys same rules as placeable items**
- [ ] **[MUST] Prevent planting on invalid tiles early** (pre-check before animation)
- [ ] **[NICE] Soft snap to grid when placing**
- [ ] **[NICE] Placement “thunk” feedback** (tiny camera shake + SFX on successful place)

## Systems

- [ ] **[NICE] Quests**: Create `QuestManager` and quest system
- [ ] **[NICE] Input buffering for tools** (small buffer so actions feel responsive)
- [ ] **[NICE] Interaction highlight outline** (tile/entity under cursor or in front of player)

## Depth sorting

- [ ] **[MUST] Z Index**: Manage Z index properly (ground - shadows - walls - player)
    - [ ] **[MUST] Implement dynamic depth sorting (Y-sort)** (preferred solution vs. manual swaps)
        - [ ] **[MUST] Player in front of tall sprites when Y > sprite base**
        - [ ] **[MUST] Player behind tall sprites when Y < sprite base**
    - [ ] **[NICE] Trees use split sprite or depth offset**
        - [ ] **[NICE] Trunk determines depth**
        - [ ] **[NICE] Canopy ignored for sorting**
    - [ ] **[MUST] Avoid manual Z-index swaps**
    - [ ] **[MUST] Centralize depth logic in renderer, not entity logic**

## Player Energy and Actions

- [ ] **[LATER] Decide if harvesting consumes energy**
- [ ] **[MUST] Energy drains per tool use** (data-driven per tool/action)
- [ ] **[MUST] Energy at/near zero affects player**
    - [ ] **[MUST] Reduce movement speed**
    - [ ] **[LATER] Auto sleep when threshold is hit**
- [ ] **[NICE] Slight magnetism toward interactables** (micro nudge; must not feel like auto-walk)
- [ ] **[NICE] World item pickup feedback**: play pickup SFX/VFX when `Item` is collected (and some feedback for partial pickup when inventory is full)
    - [ ] **[NICE] Pickup partial feedback when inventory is full** (SFX/VFX + message)

## NPCs (Stardew Feel) (Only if we find it necessary to change current behaviour)

- [ ] **[NICE] Idle NPCs collide with player**
- [ ] **[LATER] Idle NPCs do not move when pushed**
- [ ] **[LATER] Moving NPCs collision behavior**
    - [ ] **[LATER] Stop when colliding with player**
    - [ ] **[LATER] Wait X seconds**
    - [ ] **[LATER] Ignore collision after timeout** (continue path even if overlapping)
- [ ] **[LATER] Prevent teleport/snap-back when collision resolves**
- [ ] **[LATER] Ensure collision-ignore is temporary and resets**
- [ ] **[LATER] Verify hitbox matches visual sprite**
- [ ] **[LATER] Separate idle mask from movement mask**
- [ ] **[LATER] Update idle mask logic**
- [ ] **[NICE] Basic emote bubbles** (…/!/heart) for feedback without dialog

## Additional Stardew-Style QoL (Feel Boosters)

- [ ] **[NICE] Hotbar quick-swap consistency** (scroll wraps, selects last-used, etc.)
- [ ] **[NICE] “Bump” response** on invalid movement (tiny pushback + SFX)
- [ ] **[NICE] Context-sensitive prompt text** (“Water”, “Harvest”, “Talk”, “Plant”)

## Minor stuff

- [ ] **[NICE] HUD/Hotbar**: improve visuals (use a proper UI pack)
- [ ] **[LATER] Error reporting**: user-facing feedback for critical failures (save/load/etc)
- [ ] **[LATER] Async hydration**: hydrate entities in chunks to avoid frame spikes -- PERFOMANCE UPGRADE
- [ ] **[LATER] Footstep SFX by surface** (dirt/wood/grass/water edge)
