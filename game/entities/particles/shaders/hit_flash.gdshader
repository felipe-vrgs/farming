shader_type canvas_item;

// Flash parameters
uniform bool active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	if (active) {
		color.rgb = mix(color.rgb, flash_color.rgb, flash_color.a);
	}
	COLOR = color;
}
