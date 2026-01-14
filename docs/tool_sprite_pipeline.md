## Tool sprite + icon export convention

This project supports **tiered tool animations** and **per-tier icons**.

### Folder layout

For each tool type (first supported: Axe, Pickaxe):

- `assets/tools/<tool>/anims/<tier>.png`
- `assets/tools/<tool>/icons/<tier>.png`

Where `<tool>` is the folder name (e.g. `axe`, `pickaxe`) and `<tier>` is a lowercase name
(e.g. `iron`, `gold`, `platinum`, `ruby`).

### Animation sheet format (`anims/<tier>.png`)

- **Cell size**: 32x32
- **Rows**: 4 (directions), in this exact order:
  - row 0: `front`
  - row 1: `left`
  - row 2: `right`
  - row 3: `back`
- **Columns**: N (animation frames). Current tools use 3.

### Icon format (`icons/<tier>.png`)

- Single PNG image per tier (no atlas indexing).
- Each tier ToolData points `icon` directly at this texture.

### Runtime expectations

`ToolVisuals` plays animations named:

- `"<tier>_<dir>"` (example: `gold_front`)

So the generated `SpriteFrames` must contain those animation names.

### Regenerating tool resources

Two headless scripts keep resources in sync with exports:

- Rebuild tool `SpriteFrames` from `anims/*.png`:

```bash
godot --headless --script res://tools/godot/build_tool_spriteframes.gd
```

- Generate tiered `ToolData` from `icons/*.png`:

```bash
godot --headless --script res://tools/godot/generate_tiered_tools.gd
```

Outputs:

- `assets/tools/<tool>/<tool>.tres` (SpriteFrames)
- `game/entities/tools/data/tiers/<tool>_<tier>.tres` (ToolData per tier)
