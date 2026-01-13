shader_type canvas_item;

// Hair palette swap - simplified debug version
// NO color space conversions - raw comparison and replacement

uniform vec4 hair_out_0 : source_color = vec4(0.1647059, 0.07450981, 0.03137255, 1.0);
uniform vec4 hair_out_1 : source_color = vec4(0.4784314, 0.2196078, 0.1176471, 1.0);
uniform vec4 hair_out_2 : source_color = vec4(0.5764706, 0.2862745, 0.145098, 1.0);

// Key colors as normalized sRGB values
const vec3 HAIR0 = vec3(42.0, 19.0, 8.0) / 255.0;
const vec3 HAIR1 = vec3(122.0, 56.0, 30.0) / 255.0;
const vec3 HAIR2 = vec3(147.0, 73.0, 37.0) / 255.0;

const float TOL = 0.05;

bool near(vec3 a, vec3 b) {
	return all(lessThan(abs(a - b), vec3(TOL)));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a <= 0.0) {
		COLOR = vec4(0.0);
	} else if (near(tex.rgb, HAIR0)) {
		COLOR = vec4(hair_out_0.rgb, tex.a);
	} else if (near(tex.rgb, HAIR1)) {
		COLOR = vec4(hair_out_1.rgb, tex.a);
	} else if (near(tex.rgb, HAIR2)) {
		COLOR = vec4(hair_out_2.rgb, tex.a);
	} else {
		COLOR = tex;
	}
}
