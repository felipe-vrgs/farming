shader_type particles;

// UI sparkle burst for reward popups/presentations.
// Designed for low-cost celebratory "pop" in 2D UI space.

uniform float spread_amount = 360.0; // degrees
uniform float speed_min = 30.0;
uniform float speed_max = 80.0;
uniform float drift_y = -10.0; // negative = up (UI space)

uniform float scale_min = 0.25;
uniform float scale_max = 0.55;
uniform float rotation_speed_min = -6.0;
uniform float rotation_speed_max = 6.0;

// Colors
uniform vec4 color_a : source_color = vec4(1.0, 0.95, 0.65, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);

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

	// Color variation with slight brightness jitter.
	float cm = rand_from_seed(seed);
	vec4 base = mix(color_a, color_b, cm);
	float brightness = 0.85 + rand_from_seed(seed) * 0.35; // 0.85..1.2
	base.rgb *= brightness;
	COLOR = base;

	// Spawn in a small radius so it feels like a burst.
	float rx = (rand_from_seed(seed) * 2.0 - 1.0) * 3.0;
	float ry = (rand_from_seed(seed) * 2.0 - 1.0) * 3.0;
	TRANSFORM[3].xy = vec2(rx, ry);

	// Velocity: radial + slight upward drift.
	float ang = (rand_from_seed(seed) * 2.0 - 1.0) * radians(spread_amount) * 0.5;
	float spd = mix(speed_min, speed_max, rand_from_seed(seed));
	vec2 dir = vec2(cos(ang), sin(ang));
	VELOCITY.xy = dir * spd;
	VELOCITY.y += drift_y;

	// Store base scale, rotation speed and phase.
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
	TRANSFORM[3].xy += VELOCITY.xy * DELTA;

	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;
	float age_sec = t * LIFETIME;

	// Pop in fast, linger, then fade out.
	float pop_in = smoothstep(0.0, 0.08, t);
	float pop_out = 1.0 - smoothstep(0.65, 1.0, t);
	float sc = CUSTOM.x * pop_in * pop_out;

	// Spin
	float rot = (CUSTOM.w * 6.2831853) + CUSTOM.y * age_sec;
	float c = cos(rot);
	float s = sin(rot);
	TRANSFORM[0].xy = vec2(c, s) * sc;
	TRANSFORM[1].xy = vec2(-s, c) * sc;

	// Fade
	COLOR.a *= pop_out;
}
