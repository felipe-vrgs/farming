shader_type particles;

// Falling leaves particle shader for top-down pixel art.
// Uses a "ground plane" + fake height (Z) like tile_break.gdshader.
uniform float spread_amount = 8.0;

// Ground plane (XY) motion
uniform float initial_velocity_min = 4.0;
uniform float initial_velocity_max = 14.0;
uniform float wind_strength = 14.0;
uniform float wind_frequency = 1.6;

// Fake height (Z)
uniform float initial_height_min = 0.0;
uniform float initial_height_max = 10.0;
uniform float gravity = 120.0;
uniform float bounce_damping = 0.0; // 0 = no bounce (more 2D)

uniform float scale_min = 0.065;
uniform float scale_max = 0.11;
uniform float pixel_snap = 1.0;

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

	// Color variation
	float cm = rand_from_seed(seed);
	vec4 base_color = mix(color_a, color_b, cm);
	COLOR = base_color;

	// Spawn spread around emitter
	float rx = (rand_from_seed(seed) * 2.0 - 1.0) * spread_amount;
	float ry = (rand_from_seed(seed) * 2.0 - 1.0) * spread_amount;
	TRANSFORM[3].xy = vec2(rx, ry);

	// Scale
	float sc = mix(scale_min, scale_max, rand_from_seed(seed));
	TRANSFORM[0].xy = vec2(sc, 0.0);
	TRANSFORM[1].xy = vec2(0.0, sc);

	// Ground-plane velocity
	float ang = rand_from_seed(seed) * 6.2831853;
	float spd = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));
	VELOCITY.xy = vec2(cos(ang), sin(ang)) * spd;

	// CUSTOM:
	// x: current height, y: vertical velocity, z: age, w: wind phase
	CUSTOM.x = 0.0;
	CUSTOM.y = mix(initial_height_min, initial_height_max, rand_from_seed(seed));
	CUSTOM.z = 0.0;
	CUSTOM.w = rand_from_seed(seed) * 6.2831853;

	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}

void process() {
	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;

	// Fake Z-axis physics (height)
	float h = CUSTOM.x;
	float vz = CUSTOM.y;

	vz -= gravity * DELTA;
	float h_new = h + vz * DELTA;

	// Ground collision
	if (h_new <= 0.0) {
		h_new = 0.0;
		if (bounce_damping > 0.0 && abs(vz) > 20.0) {
			vz = -vz * bounce_damping;
		} else {
			vz = 0.0;
		}
	}

	CUSTOM.x = h_new;
	CUSTOM.y = vz;

	// Apply visual offset by delta height (top-down: +height moves up on screen)
	float dh = h_new - h;
	TRANSFORM[3].y -= dh;

	// Wind push (ground plane)
	float wind = sin(TIME * wind_frequency + CUSTOM.w) * wind_strength;
	VELOCITY.x += wind * DELTA;

	// Friction: more on ground, less in air
	float friction = (h_new > 1.0) ? 0.8 : 10.0;
	VELOCITY.xy -= VELOCITY.xy * friction * DELTA;

	// Move (ground plane)
	TRANSFORM[3].xy += VELOCITY.xy * DELTA;

	// No rotation: keeps it more pixel/2D.

	// Pixel snap for a more pixel-art feel.
	if (pixel_snap > 0.0) {
		vec2 p = TRANSFORM[3].xy;
		p = floor(p / pixel_snap + vec2(0.5)) * pixel_snap;
		TRANSFORM[3].xy = p;
	}

	// Fade out near end of lifetime
	float a = 1.0 - smoothstep(0.7, 1.0, t);
	COLOR.a *= a;
}
