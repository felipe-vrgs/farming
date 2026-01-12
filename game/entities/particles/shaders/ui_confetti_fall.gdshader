shader_type particles;

// UI confetti fall for reward presentation screens.
// One-shot "rain" that starts near the top and falls down with sway + spin.

uniform float spread_x = 520.0;
uniform float spawn_y_min = -24.0;
uniform float spawn_y_max = 24.0;

uniform float fall_speed_min = 90.0;
uniform float fall_speed_max = 170.0;
uniform float drift_x_min = -25.0;
uniform float drift_x_max = 25.0;

uniform float sway_amplitude = 35.0;
uniform float sway_frequency = 5.5;

uniform float scale_min = 0.35;
uniform float scale_max = 0.85;
uniform float rotation_speed_min = -5.0;
uniform float rotation_speed_max = 5.0;

// Colors
uniform vec4 color_a : source_color = vec4(1.0, 0.3, 0.7, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.9, 1.0, 1.0);

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0) s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0) s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

uint hash(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return x;
}

void start() {
	uint seed = hash(uint(INDEX) + uint(TIME * 1000.0));

	// Color variation + brightness jitter.
	float cm = rand_from_seed(seed);
	vec4 base = mix(color_a, color_b, cm);
	float brightness = 0.9 + rand_from_seed(seed) * 0.4; // 0.9..1.3
	base.rgb *= brightness;
	COLOR = base;

	// Spawn spread across the top.
	float x = (rand_from_seed(seed) * 2.0 - 1.0) * spread_x;
	float y = mix(spawn_y_min, spawn_y_max, rand_from_seed(seed));
	TRANSFORM[3].xy = vec2(x, y);

	// Downward velocity + slight horizontal drift.
	VELOCITY.x = mix(drift_x_min, drift_x_max, rand_from_seed(seed));
	VELOCITY.y = mix(fall_speed_min, fall_speed_max, rand_from_seed(seed));

	// Store base scale, rotation speed, phase, and age.
	CUSTOM.x = mix(scale_min, scale_max, rand_from_seed(seed));
	CUSTOM.y = mix(rotation_speed_min, rotation_speed_max, rand_from_seed(seed));
	CUSTOM.w = rand_from_seed(seed); // phase 0..1
	CUSTOM.z = 0.0; // age 0..1

	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}

void process() {
	// Move
	vec2 pos = TRANSFORM[3].xy;
	pos += VELOCITY.xy * DELTA;

	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;
	float age_sec = t * LIFETIME;

	// Sway (adds lateral drift)
	float phase = CUSTOM.w * 6.2831853;
	float sway = cos(age_sec * sway_frequency + phase) * sway_amplitude;
	pos.x += sway * DELTA;

	TRANSFORM[3].xy = pos;

	// Spin + scale
	float rot = phase + (CUSTOM.y * age_sec);
	float c = cos(rot);
	float s = sin(rot);
	float sc = CUSTOM.x;
	TRANSFORM[0].xy = vec2(c, s) * sc;
	TRANSFORM[1].xy = vec2(-s, c) * sc;

	// Fade near end (keep visible most of lifetime).
	float a = 1.0 - smoothstep(0.75, 1.0, t);
	COLOR.a *= a;
}
