shader_type canvas_item;
render_mode unshaded;

uniform bool use_luminance_as_alpha = true;
uniform float alpha_mult = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool hard_alpha = true;
uniform float alpha_cutoff = 0.35;
uniform bool use_texture_rgb = false;

uniform bool pixel_snap_uv = true;
uniform float alpha_gamma = 1.0; // < 1.0 boosts alpha (punchier); > 1.0 softens.
uniform bool dither_alpha = false;
uniform float dither_strength = 0.18; // 0..1, only used when dither_alpha=true.
uniform float dither_scale = 1.0; // 1.0 = aligned to screen pixels, >1 = larger pattern.

float _bayer4(vec2 frag_px) {
	ivec2 p = ivec2(mod(floor(frag_px), 4.0));
	int x = p.x;
	int y = p.y;

	// 4x4 Bayer matrix values in [0..15], normalized to [0..1).
	int v = 0;
	if (y == 0) {
		if (x == 0) v = 0; else if (x == 1) v = 8; else if (x == 2) v = 2; else v = 10;
	} else if (y == 1) {
		if (x == 0) v = 12; else if (x == 1) v = 4; else if (x == 2) v = 14; else v = 6;
	} else if (y == 2) {
		if (x == 0) v = 3; else if (x == 1) v = 11; else if (x == 2) v = 1; else v = 9;
	} else {
		if (x == 0) v = 15; else if (x == 1) v = 7; else if (x == 2) v = 13; else v = 5;
	}

	return float(v) / 16.0;
}

void fragment() {
	vec2 uv = UV;
	if (pixel_snap_uv) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		uv = (floor(uv / px) + 0.5) * px;
	}

	vec4 tex = texture(TEXTURE, uv);

	float a = tex.a;
	if (use_luminance_as_alpha) {
		a = max(tex.r, max(tex.g, tex.b));
	}

	a *= alpha_mult * tint.a;
	a = pow(clamp(a, 0.0, 1.0), max(alpha_gamma, 0.0001));

	if (hard_alpha) {
		if (dither_alpha) {
			float b = _bayer4(FRAGCOORD.xy / max(dither_scale, 0.0001));
			float cutoff = alpha_cutoff + (b - 0.5) * dither_strength;
			a = step(cutoff, a);
		} else {
			a = step(alpha_cutoff, a);
		}
	}

	vec3 rgb = (use_texture_rgb ? tex.rgb : vec3(1.0)) * tint.rgb * COLOR.rgb;
	COLOR = vec4(rgb, a * COLOR.a);
}
