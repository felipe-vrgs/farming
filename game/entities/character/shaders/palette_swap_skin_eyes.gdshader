shader_type canvas_item;

// Simple palette swap: replace specific key colors in the sprite with user-chosen colors.
// To use this, the source pixel art must paint the regions you want to recolor with these exact
// key colors (no shading/variation unless you add more keys).
//
// - SKIN_KEY (default: magenta) becomes `skin_color`
// - EYE_KEY  (default: cyan)    becomes `eye_color`

uniform vec4 skin_color : source_color = vec4(0.91, 0.74, 0.62, 1.0);
uniform vec4 eye_color : source_color = vec4(0.25, 0.55, 1.0, 1.0);

uniform vec4 skin_key : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform vec4 eye_key : source_color = vec4(0.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// Preserve transparency + exact match on key colors.
	if (c.a <= 0.0) {
		COLOR = c;
	} else if (all(equal(c, skin_key))) {
		COLOR = vec4(skin_color.rgb, c.a * skin_color.a);
	} else if (all(equal(c, eye_key))) {
		COLOR = vec4(eye_color.rgb, c.a * eye_color.a);
	} else {
		COLOR = c;
	}
}
