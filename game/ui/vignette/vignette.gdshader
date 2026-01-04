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
	// Convert UV to centered space.
	vec2 p = UV * 2.0 - 1.0;

	// Compensate aspect ratio so the vignette is circular in pixel space.
	// We scale the x-axis by the aspect ratio (width/height).
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p_scaled = p;
	p_scaled.x *= aspect;

	// Now dist is in "height units".
	// 1.0 means the distance to the top/bottom edge.
	// aspect means the distance to the left/right edge.
	float dist = length(p_scaled);

	// We want the vignette to start appearing towards the corners.
	// On 16:9, the corner distance is sqrt(aspect^2 + 1^2) = 2.03.
	float vignette = smoothstep(radius - softness, radius, dist);
	float a = vignette * strength * alpha_mul;

	COLOR = vec4(0.0, 0.0, 0.0, a);
}
