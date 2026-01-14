shader_type canvas_item;
render_mode unshaded;

// A clean, solid color for the wind/slash
uniform vec4 wind_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Subtle rim highlight to make the swish read better on all backgrounds.
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.45;
uniform float highlight_width : hint_range(0.0, 1.0) = 0.12;

// Windy motion (cheap UV distortion + smear along flow direction).
uniform vec2 flow_dir = vec2(1.0, 0.0);
uniform float flow_strength : hint_range(0.0, 0.2) = 0.03;
uniform float flow_speed : hint_range(0.0, 20.0) = 8.0;
uniform float flow_scale : hint_range(1.0, 80.0) = 28.0;
uniform float smear_strength : hint_range(0.0, 1.0) = 0.35;

// Control the "thickness" of the slash by eroding transparent edges
uniform float erosion : hint_range(0.0, 1.0) = 0.6;

// Boost the alpha after erosion to keep the core solid
uniform float alpha_boost : hint_range(1.0, 5.0) = 0.4;

void fragment() {
	vec2 dir = normalize(flow_dir);
	if (length(flow_dir) < 0.001) {
		dir = vec2(1.0, 0.0);
	}

	// Flow noise (sin-based, stable and cheap)
	float n = sin((UV.y * flow_scale) + (TIME * flow_speed));
	float n2 = sin((UV.x * (flow_scale * 0.8)) - (TIME * (flow_speed * 1.3)));
	float noise = (n * 0.6 + n2 * 0.4);

	// UV distortion + directional smear sampling
	vec2 uv_warp = UV + dir * (noise * flow_strength);
	vec4 tex0 = texture(TEXTURE, uv_warp);
	vec4 tex1 = texture(TEXTURE, uv_warp + dir * (flow_strength * 0.85));
	vec4 tex2 = texture(TEXTURE, uv_warp - dir * (flow_strength * 0.85));
	vec4 tex = tex0;
	tex.a = max(tex0.a, max(tex1.a, tex2.a) * smear_strength);

	// Start with the texture's alpha
	float a = tex.a;

	// Apply erosion: pixels with alpha below 'erosion' become transparent,
	// others are smoothed towards 1.0
	a = smoothstep(erosion, 1.0, a);

	// Apply alpha boost to make the remaining shape solid
	a = clamp(a * alpha_boost, 0.0, 1.0);

	// Tail fade along flow direction (makes it read like wind, not a flat sticker).
	// Map UV to a 0..1 ramp in flow direction.
	float proj = dot(UV - vec2(0.5), dir) + 0.5;
	float tail = smoothstep(0.0, 0.35, proj) * (1.0 - smoothstep(0.75, 1.0, proj));
	a *= clamp(tail + 0.25, 0.0, 1.0);

	// Rim highlight computed from alpha near the erosion threshold.
	float w = max(0.0001, highlight_width);
	float edge = smoothstep(erosion, erosion + w, tex.a) * (1.0 - smoothstep(erosion + w, erosion + (w * 2.0), tex.a));

	vec4 out_col = wind_color;
	out_col.rgb = mix(out_col.rgb, highlight_color.rgb, clamp(edge * highlight_strength, 0.0, 1.0));
	out_col.a *= a;

	COLOR = out_col;
}
