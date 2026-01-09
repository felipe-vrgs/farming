# Cutscene authoring rules (Dialogic)

This project uses **Dialogic 2** timelines for both NPC dialogue and cutscenes, orchestrated by `DialogueManager` and guarded by `GameFlow` world-mode state (`Enums.FlowState`).

## Timeline naming conventions

- **NPC dialogue**: `game/globals/dialogue/timelines/npcs/<npc_id>/<dialogue_id>.dtl`
  - Example: `npcs/frieren/greeting`
- **Cutscenes**: `game/globals/dialogue/timelines/cutscenes/<cutscene_id>.dtl`
  - Example: `cutscenes/frieren_house_visit`

In Dialogic event shorthand (what you type in `.dtl`):
- Use `timeline_id` without extension, e.g. `cutscenes/frieren_house_visit`.

## Actor identity rules

- Prefer stable agent ids:
  - Player: use `agent_id="player"` in cutscene events.
  - NPCs: use their `NpcConfig.npc_id` (e.g. `"frieren"`).
- The save system supports older “dynamic player ids” in some saves; cutscene systems map `player` to the effective record when needed.

## Cutscene actor component (required)

Dialogic cutscene events in this project operate on a **CutsceneActorComponent** attached to actors.

Rules:
- Player scenes must include `Components/CutsceneActorComponent`.
- NPC scenes must include `Components/CutsceneActorComponent`.
- Cutscene events like `cutscene_move_to_anchor`, `cutscene_teleport_to_anchor`, `cutscene_npc_travel_spawn`, and `cutscene_face_pos` will **fail fast** (best-effort) if the target actor is missing this component.

Additional helpers:
- `cutscene_face_pos`: face an agent toward a world position (optionally persists facing into the agent record).
- `cutscene_camera_control`: basic camera pan/zoom/reset for cutscenes (operates on `Player/Camera2D`).

## Anchors (where actors move/teleport)

Levels can expose cutscene anchors under:
- `LevelRoot/CutsceneAnchors/<AnchorName>` (a `Marker2D` or `Node2D`)

Runtime helper:
- `Runtime.find_cutscene_anchor(anchor_name)` resolves anchors in the active level scene.

Rule:
- If a cutscene needs exact placement, **author anchors in the level** and move/teleport to anchors.

## When to use blackout

Use blackout when you need to hide discontinuities:
- Teleport/warp between levels (`perform_level_warp`, travel spawns).
- Spawning/despawning actors.
- Large camera or actor position jumps.

Implementation note:
- Blackout is a **nested transaction** owned by `UIManager` (`UIManager.blackout_begin/end`).
- Dialogic cutscene events (`cutscene_blackout_*`, `cutscene_restore_actors`) call into `UIManager` so multiple systems can safely layer fades without flicker.

Typical pattern (recommended):
1. `[cutscene_blackout_begin time="..."]`
2. Spawn/warp actors (`[cutscene_npc_travel_spawn ...]`, teleports)
3. `[cutscene_blackout_end time="..."]`
4. Move actors to anchors (`[cutscene_move_to_anchor ...]`)
5. Dialogue lines
6. Restore and end (`[cutscene_restore_actors ...]`, `[end_timeline]`)

Avoid blackout when:
- You are only doing small moves that can be animated naturally.
- You want the player to see the movement as part of the cutscene.

## Persistence rules (what NOT to do during a timeline)

Cutscenes and dialogue timelines must avoid corrupting session saves mid-timeline.

Rules:
- **Do not write session saves during timelines** (no slot copy, no autosave, no agent persistence).
- If an event must move/warp actors, it should do so **without persisting**, and let the system autosave immediately after the timeline ends.

Implementation detail:
- `DialogueManager` keeps the “no-save window” minimal by autosaving right after timelines end.
- Agent travel events used during cutscenes should commit travel without persisting (timeline-safe).

## Snapshot + restore rules

Goal: “return actors to their pre-cutscene state” (best-effort).

- On cutscene start, `DialogueManager` captures snapshots via `DialogueStateSnapshotter`.
- Snapshots are captured broadly (player + spawned agents), but **restoration is explicit**:
  - Use cutscene events that call restore for the actors you want to revert.
  - Example: `[cutscene_restore_actors agent_ids="player,frieren" ...]`

Important:
- Restoring the player can require a **level warp** if the snapshot’s level differs from the active level.
- `cutscene_restore_actors` defaults to **deferring the restore until after the timeline ends** to prevent textbox/UI flicker.
  - If you need to restore mid-timeline, set `defer="false"`.

## Recommended authoring checklist

Before adding a new cutscene timeline:
- Add any required anchors to the target level scene (`CutsceneAnchors/*`).
- Ensure any spawn points/routes referenced by events exist and are valid (`game/data/spawn_points/`, `game/data/routes/`).
- Decide whether the cutscene should:
  - run in-place (CUTSCENE mode), or
  - change levels (requires blackout + warp/spawn)
- Ensure the cutscene ends with `[end_timeline]` and (if needed) a restore step.
