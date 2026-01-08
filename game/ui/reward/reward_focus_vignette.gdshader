shader_type canvas_item;

// Subtle always-on vignette to focus on the player during reward presentation.

// How dark the corners get (keep subtle; this is a happy moment).
uniform float strength : hint_range(0.0, 1.0) = 0.45;

// Radius where vignette starts (0..1 in normalized space).
uniform float radius : hint_range(0.0, 1.0) = 0.72;

// Softness of the transition band.
uniform float softness : hint_range(0.01, 1.0) = 0.35;

void fragment() {
	// Convert UV to centered space.
	vec2 p = UV * 2.0 - 1.0;

	// Compensate aspect ratio so the vignette is circular in pixel space.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p_scaled = p;
	p_scaled.x *= aspect;

	float dist = length(p_scaled);
	float vignette = smoothstep(radius - softness, radius, dist);
	vignette = vignette * vignette;
	float a = vignette * strength;

	COLOR = vec4(0.0, 0.0, 0.0, a);
}
