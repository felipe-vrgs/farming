shader_type particles;

// "Dusty" Tile Break shader
// Lots of small particles for a crumbling effect
uniform float spread_amount = 10;
uniform float initial_velocity_min = 0.0;
uniform float initial_velocity_max = 20.0;
uniform float angular_velocity_min = -10;
uniform float angular_velocity_max = 10;
uniform float scale_min = 0.4;
uniform float scale_max = 0.8;
uniform float fade_duration = 0.8;

// Bounce (Fake Z-axis)
uniform float initial_height_min = 0.0;
uniform float initial_height_max = 20.0;
uniform float gravity = 100.0;

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

	// Color: Random mix between A and B
	// This creates a gradient range instead of just A or B
	float color_mix = rand_from_seed(seed);
	vec4 base_color = mix(color_a, color_b, color_mix);

	// Flatten color to reduce "gradient" noise
	// Pick either A or B, or a strict mix (0, 0.5, 1.0)
	if (color_mix < 0.5) base_color = color_a;
	else base_color = color_b;

	// Darken slightly and add variation to avoid "neon" look
	float brightness = mix(0.8, 1.0, rand_from_seed(seed));
	// Quantize brightness to steps to keep it flat
	brightness = floor(brightness * 4.0) / 4.0;
	base_color.rgb *= brightness;

	COLOR = base_color;

	// Position:
	// Distribute randomly within the 16x16 tile, but bias slightly to center
	// to avoid spawning exactly on the grid lines which looks weird.
	float rx = (rand_from_seed(seed) * 14.0 - 7.0);
	float ry = (rand_from_seed(seed) * 14.0 - 7.0);
	TRANSFORM[3].xy = vec2(rx, ry);

	// Velocity
	// Radial explosion outward
	float angle = atan(ry, rx);

	// Add randomness
	angle += (rand_from_seed(seed) - 0.5) * 0.5;

	float speed = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));

	VELOCITY.x = cos(angle) * speed;
	VELOCITY.y = sin(angle) * speed;

	// CUSTOM data
	// z: Age
	CUSTOM.z = 0.0;
	// y: Angular Velocity
	CUSTOM.y = mix(angular_velocity_min, angular_velocity_max, rand_from_seed(seed));
	// x: Current Height (starts at 0)
	CUSTOM.x = 0.0;
	// w: Vertical Velocity (Jump strength)
	CUSTOM.w = mix(initial_height_min, initial_height_max, rand_from_seed(seed));

	// Scale:
	// Most particles should be 1px (assuming texture is small).
	// Occasional larger chunks (1.5x) but mostly small.
	float sc = mix(scale_min, scale_max, rand_from_seed(seed));

	TRANSFORM[0].xy = vec2(sc, 0.0);
	TRANSFORM[1].xy = vec2(0.0, sc);

	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}

void process() {
	// Fake Z-axis physics
	float vz = CUSTOM.w;
	float h = CUSTOM.x;

	// Apply Gravity to Vertical Velocity
	vz -= gravity * DELTA;

	// Update Height
	float h_new = h + vz * DELTA;

	// Ground collision
	if (h_new <= 0.0) {
		h_new = 0.0;
		// Bounce with dampening
		if (abs(vz) > 20.0) {
			vz = -vz * 0.4;
		} else {
			vz = 0.0;
		}
	}

	// Save state
	CUSTOM.w = vz;
	CUSTOM.x = h_new;

	// Calculate visual offset change (delta height)
	// We subtract because +Y is down, so +Height means -Y
	float dh = h_new - h;
	TRANSFORM[3].y -= dh;

	// Drag (Friction)
	// More friction on ground, less in air
	float friction = (h_new > 1.0) ? 0.5 : 8.0;
	VELOCITY -= VELOCITY * friction * DELTA;

	// Move (Ground Plane)
	vec3 pos = TRANSFORM[3].xyz;
	pos += VELOCITY * DELTA;
	TRANSFORM[3].xyz = pos;

	// Rotation (Tumbling)
	float ang_step = CUSTOM.y * DELTA;
	float c = cos(ang_step);
	float s = sin(ang_step);
	mat2 rot = mat2(vec2(c, s), vec2(-s, c));

	TRANSFORM[0].xy = rot * TRANSFORM[0].xy;
	TRANSFORM[1].xy = rot * TRANSFORM[1].xy;

	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;

	// Fade/Shrink
	float fade = clamp(t / fade_duration, 0.0, 1.0);

	uint seed = hash(uint(INDEX));
	float dither_threshold = rand_from_seed(seed);

	// If the fade progress is greater than our random threshold, kill the pixel
	if (fade > dither_threshold) {
		COLOR.a = 0.0;
	} else {
		COLOR.a = 1.0;
	}

	float scale_mod = 1.0 - (fade * 0.1);
	TRANSFORM[0].xy *= scale_mod;
	TRANSFORM[1].xy *= scale_mod;
}
