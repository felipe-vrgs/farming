shader_type canvas_item;

// Skin + eyes palette swap - simplified debug version
// NO color space conversions - raw comparison and replacement

uniform vec4 skin_out_0 : source_color = vec4(0.9764706, 0.6784314, 0.5372549, 1.0);
uniform vec4 skin_out_1 : source_color = vec4(0.9372549, 0.5568628, 0.4862745, 1.0);
uniform vec4 eye_out : source_color = vec4(0.2235294, 0.4705882, 0.6588235, 1.0);

// Key colors as normalized sRGB values
const vec3 BORDER = vec3(115.0, 0.0, 68.0) / 255.0;
const vec3 SKIN0 = vec3(249.0, 173.0, 137.0) / 255.0;
const vec3 SKIN1 = vec3(239.0, 142.0, 124.0) / 255.0;
const vec3 EYE = vec3(57.0, 120.0, 168.0) / 255.0;

const float TOL = 0.05;

bool near(vec3 a, vec3 b) {
	return all(lessThan(abs(a - b), vec3(TOL)));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a <= 0.0) {
		COLOR = vec4(0.0);
	} else if (near(tex.rgb, BORDER)) {
		COLOR = tex; // keep border
	} else if (near(tex.rgb, SKIN0)) {
		COLOR = vec4(skin_out_0.rgb, tex.a);
	} else if (near(tex.rgb, SKIN1)) {
		COLOR = vec4(skin_out_1.rgb, tex.a);
	} else if (near(tex.rgb, EYE)) {
		COLOR = vec4(eye_out.rgb, tex.a);
	} else {
		COLOR = tex; // no match, keep original
	}
}
