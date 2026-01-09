# Dialogic variables in this project

This project uses **Dialogic 2** variables for branching/persistence, but treats runtime systems (`QuestManager`, `RelationshipManager`, etc.) as the **source of truth**.

There are two parts:

1. **Default schema** (so variables show up in Dialogic’s Variables editor)
2. **Runtime sync** (so values reflect the actual game state, and don’t drift across save/load)

## Variable schema (stable paths)

### Quests

```
quests.<quest_id>.active      (bool)
quests.<quest_id>.completed   (bool)
quests.<quest_id>.step        (int)   # “current step index” semantics
```

- `quest_id` comes from `QuestResource.id` under `res://game/data/quests/`.

### Relationships

```
relationships.<npc_id>.units  (int)   # half-heart units (0..20)
```

- `npc_id` comes from `NpcConfig.npc_id` under `res://game/entities/npc/configs/`.
- Units are **half-hearts**: 2 units = 1 heart.

### Timeline completion

Dialogic timeline completion is tracked via:

```
completed_timelines.<path_segments...> (bool)
```

This is set by `DialogueManager` after timelines end.

## Runtime sync (authoritative)

### Live updates during gameplay

- **Quests**: `DialogueManager` listens to `EventBus.quest_started/quest_step_completed/quest_completed` and updates Dialogic variables via `DialogicFacade.set_quest_*`.
- **Relationships**: `DialogueManager` listens to `EventBus.relationship_changed` and updates `relationships.<npc_id>.units` via `DialogicFacade.set_relationship_units`.

Relevant code:
- `game/globals/dialogue/dialogue_manager.gd`
- `game/globals/dialogue/dialogic_facade.gd`

### Save/load coherence (prevent drift)

During load/continue, `GameFlow` hydrates runtime managers first and then forces Dialogic variables to match:

- `DialogueManager.sync_quest_state_from_manager()`
- `DialogueManager.sync_relationship_state_from_manager()`

This intentionally overwrites the `quests` and `relationships` roots in `Dialogic.VAR` to prevent stale `DialogueSave` values from drifting from runtime truth.

Relevant code:
- `game/globals/game_flow/game_flow.gd`

## Making variables show up in Dialogic’s Variables editor

Dialogic’s Variables editor is driven by `ProjectSettings["dialogic/variables"]`.
Runtime-created paths won’t automatically appear in the editor until they exist in that default schema.

This repo includes an editor script that **merges** in missing quest/relationship paths without clobbering existing variables:

- `tools/generate_dialogic_variables.gd`

It also predeclares `completed_timelines.*` entries for authored `.dtl` files so timeline completion vars show up in the editor.

### How to run it

1. Open `tools/generate_dialogic_variables.gd` in the Godot editor.
2. Run the script as an **EditorScript** (Script editor → Run).
3. It will update `ProjectSettings["dialogic/variables"]` and save `project.godot`.

After running, open Dialogic → Variables and you should see the generated `quests/*` and `relationships/*` entries.

## Conventions / pitfalls

- **Quest step semantics**: Dialogic stores the **current step index**; the quest event `quest_step_completed` uses **completed-step** semantics, so code must add 1 when syncing.
- **Don’t hand-edit runtime-backed values**: treat defaults as “editor visibility + reset values”, and rely on runtime sync for the real values.
- **Prefer extension layer**: don’t modify `addons/dialogic` directly; use `addons/dialogic_additions` or project scripts.
