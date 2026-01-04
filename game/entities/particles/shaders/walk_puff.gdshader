shader_type particles;

uniform float spread_amount = 20.0;
uniform float initial_velocity_min = 10.0;
uniform float initial_velocity_max = 20.0;
uniform float scale_min = 0.4;
uniform float scale_max = 0.8;
uniform float gravity = 200.0;
uniform float fade_start = 0.8;
uniform float fade_duration = 0.5;

// Colors
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(1.0);

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

	// Color mix: Pick A or B, but then vary brightness
	float color_mix = rand_from_seed(seed);
	vec4 base_color = (color_mix < 0.5) ? color_a : color_b;

	// JUICE: Vary brightness so particles don't blend perfectly with ground
	float brightness = 0.8 + rand_from_seed(seed) * 0.4; // 0.8 to 1.2
	base_color.rgb *= brightness;

	COLOR = base_color;

	// Random position offset
	float rx = (rand_from_seed(seed) - 0.5) * 6.0;
	float ry = (rand_from_seed(seed) - 0.5) * 2.0;
	TRANSFORM[3].xy = vec2(rx, ry);

	// Upward velocity with spread
	float angle = -PI/2.0 + (rand_from_seed(seed) - 0.5) * radians(spread_amount);
	float speed = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));

	VELOCITY.x = cos(angle) * speed;
	VELOCITY.y = sin(angle) * speed;

	// Scale
	float sc = mix(scale_min, scale_max, rand_from_seed(seed));
	TRANSFORM[0].xy = vec2(sc, 0.0);
	TRANSFORM[1].xy = vec2(0.0, sc);

	CUSTOM.z = 0.0; // Age

	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}

void process() {
	// Apply gravity
	VELOCITY.y += gravity * DELTA;

	// Move
	vec3 pos = TRANSFORM[3].xyz;
	pos += VELOCITY * DELTA;
	TRANSFORM[3].xyz = pos;

	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;

	// Fade/Shrink
	float fade = clamp(t / fade_duration, 0.0, fade_start);
	COLOR.a = fade_start - fade;
	float scale_mod = 1.0 - (fade * 0.1);
	TRANSFORM[0].xy *= scale_mod;
	TRANSFORM[1].xy *= scale_mod;
}
