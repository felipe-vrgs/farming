shader_type canvas_item;

// Simple radial glow for small UI icons (reward popups, etc).
uniform vec4 glow_color : source_color = vec4(1.0, 0.90, 0.45, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float radius : hint_range(0.0, 1.0) = 0.65;
uniform float softness : hint_range(0.01, 1.0) = 0.35;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = 1.0 - smoothstep(radius - softness, radius, d);
	a = a * a * strength;
	COLOR = vec4(glow_color.rgb, a * glow_color.a);
}
