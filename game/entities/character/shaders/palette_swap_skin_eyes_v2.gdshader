shader_type canvas_item;

// Skin + eyes palette swap for modular character layers.
//
// Key matching is done in *linear space* (what texture() returns) against
// linearized versions of the sRGB key colors. This avoids sRGB roundtrip issues
// and keeps border untouched.
//
// Border is explicitly ignored (never swapped).

// Colors are authored/selected in sRGB (Color/Color8 from UI), but canvas_item rendering is linear.
// `source_color` makes Godot convert sRGB -> linear for us, so saturation/brightness match input.
uniform vec4 skin_out_0 : source_color = vec4(0.9764706, 0.6784314, 0.5372549, 1.0); // #f9ad89
uniform vec4 skin_out_1 : source_color = vec4(0.9372549, 0.5568628, 0.4862745, 1.0); // #ef8e7c
uniform vec4 eye_out : source_color = vec4(0.2235294, 0.4705882, 0.6588235, 1.0); // #3978a8

// Key colors in *8-bit sRGB* space.
const vec3 BORDER_SRGB8 = vec3(115.0, 0.0, 68.0);      // #730044
const vec3 SKIN0_SRGB8 = vec3(249.0, 173.0, 137.0);    // #f9ad89
const vec3 SKIN1_SRGB8 = vec3(239.0, 142.0, 124.0);    // #ef8e7c
const vec3 EYE_SRGB8 = vec3(57.0, 120.0, 168.0);       // #3978a8

float linear_to_srgb_1(float c) {
	// IEC 61966-2-1 conversion (scalar).
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
	// Robust match across import paths:
	// - some textures deliver raw sRGB in texture()
	// - others deliver linear in texture()
	// We quantize both and match in 8-bit space to avoid epsilon issues.
	return all(equal(raw8, key8)) || all(equal(srgb8_from_linear, key8));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 vcol = COLOR; // includes modulate/self_modulate

	vec3 rgb = tex.rgb;
	vec3 raw8 = to_rgb8(rgb);
	vec3 srgb8 = to_rgb8(linear_to_srgb(clamp(rgb, 0.0, 1.0)));

	vec4 out_col = vec4(tex.rgb, tex.a);

	// No early returns (Godot canvas_item fragment forbids them).
	if (tex.a <= 0.0) {
		// Avoid edge halos when filtering: transparent pixels should contribute no color.
		out_col = vec4(0.0, 0.0, 0.0, 0.0);
	} else if (match_key8(raw8, srgb8, BORDER_SRGB8)) {
		// Ignore border always.
		out_col = vec4(tex.rgb, tex.a);
	} else if (match_key8(raw8, srgb8, SKIN0_SRGB8)) {
		out_col = vec4(skin_out_0.rgb, tex.a * skin_out_0.a);
	} else if (match_key8(raw8, srgb8, SKIN1_SRGB8)) {
		out_col = vec4(skin_out_1.rgb, tex.a * skin_out_1.a);
	} else if (match_key8(raw8, srgb8, EYE_SRGB8)) {
		out_col = vec4(eye_out.rgb, tex.a * eye_out.a);
	}

	// Re-apply vertex color after swapping.
	COLOR = vec4(out_col.rgb * vcol.rgb, out_col.a * vcol.a);
}
