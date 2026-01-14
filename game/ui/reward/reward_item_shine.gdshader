shader_type canvas_item;

// Reward item shine: soft glow + diagonal sweep highlight.
// Designed for Sprite2D item icons (uses alpha mask).

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0, 0.01) = 1.15;
uniform float glow_size : hint_range(0.0, 6.0, 0.01) = 2.2; // in texture pixels

uniform vec4 sweep_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sweep_strength : hint_range(0.0, 3.0, 0.01) = 1.05;
uniform float sweep_width : hint_range(0.01, 1.0, 0.01) = 0.18; // band width in UV space
uniform float sweep_speed : hint_range(0.01, 5.0, 0.01) = 0.9; // cycles per second
uniform float sweep_angle : hint_range(-3.1416, 3.1416, 0.001) = -0.75; // radians


void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;

	// Soft glow derived from nearby alpha coverage.
	vec2 px = TEXTURE_PIXEL_SIZE * glow_size;
	float max_a = a;
	max_a = max(max_a, texture(TEXTURE, UV + vec2( px.x,  0.0)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-px.x,  0.0)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2( 0.0,  px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2( 0.0, -px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	// Glow only outside the core, softened.
	float glow_mask = clamp(max_a - a, 0.0, 1.0);
	glow_mask = smoothstep(0.0, 1.0, glow_mask);
	vec3 glow = glow_color.rgb * glow_mask * glow_strength;

	// Diagonal sweep band (only where the sprite exists).
	vec2 dir = normalize(vec2(cos(sweep_angle), sin(sweep_angle)));
	float coord = dot((UV - vec2(0.5)), dir);
	float t = fract(TIME * sweep_speed);
	float center = mix(-0.85, 0.85, t);
	float half_w = sweep_width * 0.5;
	float band = 1.0 - smoothstep(half_w, half_w + 0.06, abs(coord - center));
	band *= a; // keep highlight inside the sprite
	vec3 sweep = sweep_color.rgb * band * sweep_strength;

	base.rgb += glow + sweep;
	COLOR = base;
}
