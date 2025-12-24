shader_type canvas_item;
render_mode unshaded;

// A clean, solid color for the wind/slash
uniform vec4 wind_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Control the "thickness" of the slash by eroding transparent edges
uniform float erosion : hint_range(0.0, 1.0) = 0.6;

// Boost the alpha after erosion to keep the core solid
uniform float alpha_boost : hint_range(1.0, 5.0) = 0.4;

void fragment() {
	// Sample the sprite texture (the animation frame)
	vec4 tex = texture(TEXTURE, UV);
	
	// Start with the texture's alpha
	float a = tex.a;
	
	// Apply erosion: pixels with alpha below 'erosion' become transparent,
	// others are smoothed towards 1.0
	a = smoothstep(erosion, 1.0, a);
	
	// Apply alpha boost to make the remaining shape solid
	a = clamp(a * alpha_boost, 0.0, 1.0);
	
	// Output the wind color with the modified alpha
	COLOR = wind_color;
	COLOR.a *= a;
}
