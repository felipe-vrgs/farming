shader_type canvas_item;

// Hair-only palette swap for modular hair layer.
// Border is explicitly ignored (never swapped).
// Matching is done in linear space against linearized sRGB keys.

// Colors are authored/selected in sRGB (Color/Color8 from UI), but canvas_item rendering is linear.
// `source_color` makes Godot convert sRGB -> linear for us, so saturation/brightness match input.
uniform vec4 hair_out_0 : source_color = vec4(0.1647059, 0.07450981, 0.03137255, 1.0); // #2a1308
uniform vec4 hair_out_1 : source_color = vec4(0.4784314, 0.2196078, 0.1176471, 1.0); // #7a381e
uniform vec4 hair_out_2 : source_color = vec4(0.5764706, 0.2862745, 0.145098, 1.0); // #934925

// Key colors in *8-bit sRGB* space.
const vec3 BORDER_SRGB8 = vec3(115.0, 0.0, 68.0);     // #730044
const vec3 HAIR0_SRGB8 = vec3(42.0, 19.0, 8.0);       // #2a1308
const vec3 HAIR1_SRGB8 = vec3(122.0, 56.0, 30.0);     // #7a381e
const vec3 HAIR2_SRGB8 = vec3(147.0, 73.0, 37.0);     // #934925

float linear_to_srgb_1(float c) {
	if (c <= 0.0031308) {
		return c * 12.92;
	}
	return 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

vec3 linear_to_srgb(vec3 c) {
	return vec3(
		linear_to_srgb_1(c.r),
		linear_to_srgb_1(c.g),
		linear_to_srgb_1(c.b)
	);
}

vec3 to_rgb8(vec3 c01) {
	return floor(clamp(c01, 0.0, 1.0) * 255.0 + 0.5);
}

bool match_key8(vec3 raw8, vec3 srgb8_from_linear, vec3 key8) {
	return all(equal(raw8, key8)) || all(equal(srgb8_from_linear, key8));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 vcol = COLOR;

	vec3 rgb = tex.rgb;
	vec3 raw8 = to_rgb8(rgb);
	vec3 srgb8 = to_rgb8(linear_to_srgb(clamp(rgb, 0.0, 1.0)));

	vec4 out_col = vec4(tex.rgb, tex.a);

	// No early returns (Godot canvas_item fragment forbids them).
	if (tex.a <= 0.0) {
		out_col = vec4(0.0, 0.0, 0.0, 0.0);
	} else if (match_key8(raw8, srgb8, BORDER_SRGB8)) {
		out_col = vec4(tex.rgb, tex.a);
	} else if (match_key8(raw8, srgb8, HAIR0_SRGB8)) {
		out_col = vec4(hair_out_0.rgb, tex.a * hair_out_0.a);
	} else if (match_key8(raw8, srgb8, HAIR1_SRGB8)) {
		out_col = vec4(hair_out_1.rgb, tex.a * hair_out_1.a);
	} else if (match_key8(raw8, srgb8, HAIR2_SRGB8)) {
		out_col = vec4(hair_out_2.rgb, tex.a * hair_out_2.a);
	}

	COLOR = vec4(out_col.rgb * vcol.rgb, out_col.a * vcol.a);
}
