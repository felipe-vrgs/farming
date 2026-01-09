class_name GrantRewardRow
extends RefCounted

## GrantRewardRow
## A typed payload for the GRANT_REWARD flow (Quest rewards, cutscene rewards, etc.).

var icon: Texture2D = null
var count: int = 1
var title: String = ""

# Optional metadata for richer UI (safe to ignore by consumers).
var kind: StringName = &""  # e.g. &"item", &"money", &"relationship"
var npc_id: StringName = &""
var delta_units: int = 0
