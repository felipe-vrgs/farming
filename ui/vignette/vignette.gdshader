shader_type canvas_item;

// Overall on/off fade (0..1). Driven by script tween.
uniform float alpha_mul : hint_range(0.0, 1.0) = 0.0;

// How dark the corners get at full alpha_mul (subtle default).
uniform float strength : hint_range(0.0, 1.0) = 0.06;

// Radius where vignette starts (0..1 in normalized space).
uniform float radius : hint_range(0.0, 1.0) = 0.88;

// Softness of the transition band.
uniform float softness : hint_range(0.01, 1.0) = 0.25;

void fragment() {
	// Convert UV to centered space and compensate aspect ratio so corners look consistent.
	vec2 p = UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	p.x *= aspect;

	float dist = length(p);
	float vignette = smoothstep(radius - softness, radius, dist);
	float a = vignette * strength * alpha_mul;

	COLOR = vec4(0.0, 0.0, 0.0, a);
}

