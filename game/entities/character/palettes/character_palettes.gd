class_name CharacterPalettes
extends Object

## Central place for character palette presets + helpers.

const DEFAULT_SKIN_MAIN := Color8(0xF9, 0xAD, 0x89, 0xFF)  # #f9ad89
const DEFAULT_SKIN_SECONDARY := Color8(0xEF, 0x8E, 0x7C, 0xFF)  # #ef8e7c
const DEFAULT_EYE := Color8(0x39, 0x78, 0xA8, 0xFF)  # #3978a8
const DEFAULT_HAIR_BASE := Color8(0x2A, 0x13, 0x08, 0xFF)  # #2a1308

# 10 skin tone presets (2-tone). Names are UI-facing.
const SKIN_TONES: Array[Dictionary] = [
	{
		"name": "01 Porcelain",
		"main": Color8(0xFF, 0xCC, 0xB3, 0xFF),
		"secondary": Color8(0xF5, 0xB2, 0x9D, 0xFF),
	},
	{
		"name": "02 Light",
		"main": Color8(0xF9, 0xAD, 0x89, 0xFF),
		"secondary": Color8(0xEF, 0x8E, 0x7C, 0xFF),
	},
	{
		"name": "03 Peach",
		"main": Color8(0xF4, 0xA0, 0x7F, 0xFF),
		"secondary": Color8(0xE7, 0x86, 0x74, 0xFF),
	},
	{
		"name": "04 Warm",
		"main": Color8(0xEA, 0x92, 0x73, 0xFF),
		"secondary": Color8(0xDC, 0x7C, 0x67, 0xFF),
	},
	{
		"name": "05 Tan",
		"main": Color8(0xDD, 0x83, 0x60, 0xFF),
		"secondary": Color8(0xC9, 0x70, 0x54, 0xFF),
	},
	{
		"name": "06 Bronze",
		"main": Color8(0xC9, 0x72, 0x54, 0xFF),
		"secondary": Color8(0xB4, 0x60, 0x4A, 0xFF),
	},
	{
		"name": "07 Brown",
		"main": Color8(0xB1, 0x61, 0x46, 0xFF),
		"secondary": Color8(0x9B, 0x52, 0x3E, 0xFF),
	},
	{
		"name": "08 Deep",
		"main": Color8(0x96, 0x4D, 0x38, 0xFF),
		"secondary": Color8(0x84, 0x41, 0x32, 0xFF),
	},
	{
		"name": "09 Dark",
		"main": Color8(0x7E, 0x3E, 0x2D, 0xFF),
		"secondary": Color8(0x6E, 0x33, 0x27, 0xFF),
	},
	{
		"name": "10 Midnight",
		"main": Color8(0x4E, 0x22, 0x19, 0xFF),
		"secondary": Color8(0x40, 0x1B, 0x14, 0xFF),
	},
]


static func skin_tone_count() -> int:
	return SKIN_TONES.size()


static func skin_tone_name(index: int) -> String:
	var i := clampi(index, 0, SKIN_TONES.size() - 1)
	return String(SKIN_TONES[i].get("name", "Skin"))


static func skin_main(index: int) -> Color:
	var i := clampi(index, 0, SKIN_TONES.size() - 1)
	return SKIN_TONES[i].get("main", DEFAULT_SKIN_MAIN) as Color


static func skin_secondary(index: int) -> Color:
	var i := clampi(index, 0, SKIN_TONES.size() - 1)
	return SKIN_TONES[i].get("secondary", DEFAULT_SKIN_SECONDARY) as Color


static func derive_hair_tones(base: Color) -> Array[Color]:
	# Generate 3 tones from a base color: shadow / mid / highlight.
	#
	# The picked color is treated as the canonical/mid tone (direct replacement).
	# Shadow/highlight are derived without hue shifts so saturated colors (like blue)
	# still read as the chosen color across the whole palette.
	const SHADOW_FACTOR := 0.55
	const HIGHLIGHT_FACTOR := 1.6

	var mid := base
	var shadow := Color(
		clampf(base.r * SHADOW_FACTOR, 0.0, 1.0),
		clampf(base.g * SHADOW_FACTOR, 0.0, 1.0),
		clampf(base.b * SHADOW_FACTOR, 0.0, 1.0),
		base.a
	)
	# Brighten by scaling channels (then clamp), instead of lerping toward white.
	# This preserves pure hues (e.g. 0,0,1 stays blue in highlights instead of turning cyan).
	var highlight := Color(
		clampf(base.r * HIGHLIGHT_FACTOR, 0.0, 1.0),
		clampf(base.g * HIGHLIGHT_FACTOR, 0.0, 1.0),
		clampf(base.b * HIGHLIGHT_FACTOR, 0.0, 1.0),
		base.a
	)

	return [shadow, mid, highlight]
