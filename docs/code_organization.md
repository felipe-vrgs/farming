# Code organization guide (where to put code)

This repo follows a “systems + components” structure. Use this guide to keep new code consistent and easy to maintain.

## Quick rules

- **Gameplay behavior that lives on an entity** → put it in `game/entities/components/` as a component.
- **Long-lived orchestration / cross-scene state** → put it in `game/globals/` (usually behind a facade or manager).
- **Pure data** → put it in `.tres` resources under `game/data/` (or under the owning feature folder).
- **UI behavior** → put it in `game/ui/` and let `UIManager` own screen lifetime.
- **Debug-only tools** → put it in `debug/` and guard with `OS.is_debug_build()`.
- **Third-party plugins** → keep them in `addons/` and avoid editing upstream code unless necessary.

## `game/globals/` (autoload services)

Use `game/globals/` for:
- **Orchestration** (save/load, scene changing, flow states, time).
- **Authoritative cross-level state** (agents, dialogue variables).
- **Facades** that simplify complex subsystems (`WorldGrid`, `DialogicFacade`).

Avoid:
- Putting “per-entity behavior” here (that becomes hard to reuse and test).
- Making gameplay entities call each other directly via singletons; prefer `EventBus` signals or component queries.

## `game/entities/` (things that exist in the world)

Use `game/entities/` for:
- Player/NPC/plants/items/tools/travel zones, their scenes and scripts.
- State machines and state scripts (`game/entities/state_machine/`, `game/entities/*/states/`).

Guidelines:
- Entities should be **scene-local** and disposable (loads and level changes can recreate them).
- If something must survive across levels, persist it via a save model (`AgentRecord`, `LevelSave`, etc.) and hydrate it when needed.

Notes:
- **Plant visuals**: plant graphics are atlas-driven via `PlantData` (`game/entities/plants/types/*`), and each `Plant` persists a `variant_index` so visuals remain stable across save/load.

## `game/entities/components/` (reusable behavior)

Use components for:
- Interactions (`interactable_component.gd`, `talk_on_interact.gd`, etc.).
- Persistence hooks (`save_component.gd`, `persistent_entity_component.gd`).
- Identity/state bridging (`agent_component.gd`).
- World integration (`grid_occupant_component.gd`, `raycell_component.gd`).

Component design tips:
- Prefer small components with a single responsibility.
- Expose data via exported properties or resources (`*.tres`) rather than hardcoding.
- If a component needs to communicate outward, emit `EventBus` signals or call a facade (`WorldGrid`, `Runtime`) instead of reaching into other nodes.

## `game/levels/` (level scenes)

Levels should:
- Use `LevelRoot` / `FarmLevelRoot` scripts.
- Provide stable `level_id` (from `Enums.Levels`).
- Provide conventional child nodes used by systems:
  - `CutsceneAnchors` (Node2D) with `Marker2D` children for anchors.

Avoid:
- Putting global state or long-lived managers inside a level scene.

## `game/ui/` (screens + HUD)

UI should:
- Be instantiated and owned by `UIManager`.
- Be resilient to SceneTree pause (`PROCESS_MODE_ALWAYS`) where needed (loading, dialogue overlays).
- Rebind to the new Player instance after loads (HUD already supports `rebind()`).

Notes:
- If you need a screen fade/blackout, use the centralized `UIManager.blackout_begin/end` (nested-safe) instead of re-implementing fades in gameplay code.

## `game/data/` (resources and authored content)

Put “authored content” here when it is feature-agnostic:
- routes (`game/data/routes/`)
- spawn points (`game/data/spawn_points/`)
- global configs (`game/data/stats_config.gd`, etc.)

Feature-specific resources can live under the feature folder:
- NPC configs and schedules live under `game/entities/npc/configs/` and `game/entities/npc/schedules/`.

## `addons/` (plugins)

- `addons/dialogic/` is vendored third-party code.
- `addons/dialogic_additions/` is *your* extension layer (custom events and helpers).

Rule:
- Prefer extending via `dialogic_additions` instead of modifying `addons/dialogic` directly.

## `debug/` (dev tools)

Everything here should be:
- Safe to ship (but no-op / removed in non-debug builds), or
- Explicitly guarded so release builds don’t pay runtime cost.
