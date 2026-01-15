shader_type canvas_item;

// Hair palette swap - simplified debug version
// NO color space conversions - raw comparison and replacement

uniform vec4 hair_out_0 : source_color = vec4(0.1647059, 0.07450981, 0.03137255, 1.0);
uniform vec4 hair_out_1 : source_color = vec4(0.3019608, 0.1607843, 0.1019608, 1.0);
uniform vec4 hair_out_2 : source_color = vec4(0.454902, 0.2431373, 0.1490196, 1.0);
uniform vec4 hair_out_3 : source_color = vec4(0.6, 0.3215686, 0.2, 1.0);

// Key colors as normalized sRGB values
const vec3 HAIR0 = vec3(42.0, 19.0, 8.0) / 255.0;
const vec3 HAIR1 = vec3(77.0, 41.0, 26.0) / 255.0;
const vec3 HAIR2 = vec3(116.0, 62.0, 38.0) / 255.0;
const vec3 HAIR3 = vec3(153.0, 82.0, 51.0) / 255.0;

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
	} else if (near(tex.rgb, HAIR3)) {
		COLOR = vec4(hair_out_3.rgb, tex.a);
	} else {
		COLOR = tex;
	}
}
