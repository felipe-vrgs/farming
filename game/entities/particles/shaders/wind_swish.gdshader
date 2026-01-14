shader_type canvas_item;
render_mode unshaded;

// Pixel-art-friendly wind swish shader for tool hit effects.
// Creates an ethereal, wispy wind effect rather than a solid slash.

// Main color for the swish (subtle tint, not overpowering)
uniform vec4 wind_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float color_intensity : hint_range(0.0, 1.0) = 0.3; // How much color shows (low = more white/wind-like)

// Rim/edge highlight for visibility on dark backgrounds
uniform vec4 rim_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.2;

// Alpha threshold for pixel edges
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.1;

// Overall transparency (makes it feel like wind, not solid)
uniform float base_opacity : hint_range(0.0, 1.0) = 0.6;

// Wispy effect: creates gaps/fragments for wind-like feel
uniform bool enable_wispy = true;
uniform float wispy_density : hint_range(0.0, 1.0) = 0.4; // Higher = more gaps
uniform float wispy_scale : hint_range(4.0, 32.0) = 12.0; // Pattern size

// Speed lines trailing effect
uniform bool enable_speed_lines = true;
uniform float speed_line_offset : hint_range(0.0, 0.15) = 0.01;
uniform float speed_line_alpha : hint_range(0.0, 1.0) = 0.3;

// Directional fade (makes slash feel like motion)
uniform vec2 fade_direction = vec2(1.0, 0.0);
uniform float fade_strength : hint_range(0.0, 1.0) = 0.1;
uniform int fade_steps : hint_range(1, 8) = 4;

// Center-to-edge alpha falloff (core visible, edges fade)
uniform float center_strength : hint_range(0.0, 1.0) = 0.5;

// Pseudo-random noise for wispy effect (deterministic based on UV)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Sample the base texture
	vec4 tex = texture(TEXTURE, UV);
	float base_alpha = tex.a;

	// Speed lines: sample texture offset to create trailing effect
	float trail_alpha = 0.0;
	if (enable_speed_lines && length(fade_direction) > 0.001) {
		vec2 dir = normalize(fade_direction);
		vec4 trail1 = texture(TEXTURE, UV - dir * speed_line_offset);
		vec4 trail2 = texture(TEXTURE, UV - dir * speed_line_offset * 2.0);
		float trail_mask = step(base_alpha, 0.01);
		trail_alpha = max(trail1.a, trail2.a * 0.5) * speed_line_alpha * trail_mask;
	}

	// Combine base and trail alpha
	float combined_alpha = max(base_alpha, trail_alpha);

	// Hard cutoff for crisp pixel edges
	float pixel_visible = step(alpha_cutoff, combined_alpha);

	// === WISPY EFFECT: Create wind-like gaps ===
	float wispy_factor = 1.0;
	if (enable_wispy && pixel_visible > 0.5) {
		// Grid-based noise that respects pixel boundaries
		vec2 grid_uv = floor(UV * wispy_scale);
		float noise = hash(grid_uv);

		// Create gaps where noise is below threshold
		// Edge pixels are less likely to be removed (preserve shape silhouette)
		float edge_preserve = step(combined_alpha, 0.7); // Lower alpha = edge
		float gap_threshold = wispy_density * (1.0 - edge_preserve * 0.5);

		wispy_factor = step(gap_threshold, noise);
	}

	// === CENTER-TO-EDGE FALLOFF ===
	// Pixels further from center of the UV are more transparent
	float dist_from_center = length(UV - vec2(0.5)) * 2.0; // 0 at center, ~1.4 at corners
	float center_falloff = 1.0 - (dist_from_center * center_strength * 0.5);
	center_falloff = clamp(center_falloff, 0.3, 1.0);

	// === DIRECTIONAL FADE ===
	float dir_fade = 1.0;
	if (fade_strength > 0.001 && length(fade_direction) > 0.001) {
		vec2 dir = normalize(fade_direction);
		float proj = dot(UV - vec2(0.5), dir) + 0.5;
		proj = clamp(proj, 0.0, 1.0);
		float quantized = floor(proj * float(fade_steps)) / float(fade_steps);
		dir_fade = mix(1.0 - fade_strength, 1.0, quantized);
	}

	// === FINAL ALPHA ===
	float final_alpha = pixel_visible * wispy_factor * center_falloff * dir_fade * base_opacity;

	// === EDGE DETECTION for rim highlight ===
	vec2 pixel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
	float a_left = texture(TEXTURE, UV - vec2(pixel_size.x, 0.0)).a;
	float a_right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;
	float a_up = texture(TEXTURE, UV - vec2(0.0, pixel_size.y)).a;
	float a_down = texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;

	float is_edge = 0.0;
	if (base_alpha > alpha_cutoff) {
		float neighbor_empty = step(a_left, alpha_cutoff) + step(a_right, alpha_cutoff)
							 + step(a_up, alpha_cutoff) + step(a_down, alpha_cutoff);
		is_edge = step(0.5, neighbor_empty);
	}

	// === COLOR MIXING ===
	// Start with white (wind-like), blend in color based on intensity
	vec3 base_white = vec3(1.0);
	vec3 tinted = mix(base_white, wind_color.rgb, color_intensity);

	// Apply rim highlight on edges
	vec3 out_color = mix(tinted, rim_color.rgb, is_edge * rim_intensity);

	// Output
	COLOR = vec4(out_color, final_alpha * wind_color.a);
}
