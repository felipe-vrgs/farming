shader_type particles;

// Standard particle parameters
uniform float spread_amount = 0.5;
uniform float initial_velocity_min = 40.0;
uniform float initial_velocity_max = 80.0;

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
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
	
	// Random position within the center of the tile
	// We want to emit from the "hit" area, mainly center
	float rx = rand_from_seed(seed) * 2.0 - 1.0; // -1 to 1
	float ry = rand_from_seed(seed) * 2.0 - 1.0;
	
	// Circle distribution for position
	TRANSFORM[3].xy = vec2(rx, ry) * 4.0; // 4 pixel radius from center
	
	// Velocity: Explode outwards
	float angle = rand_from_seed(seed) * 6.28;
	float speed = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));
	
	VELOCITY.x = cos(angle) * speed;
	VELOCITY.y = sin(angle) * speed;
	
	// Upward bias (shovel lift)
	VELOCITY.y -= 50.0;
	
	// Store the random UV offset for this particle in Custom
	// We want each particle to grab a random pixel from the tile texture
	float uv_x = rand_from_seed(seed);
	float uv_y = rand_from_seed(seed);
	CUSTOM.xy = vec2(uv_x, uv_y);
	
	// Duration/Lifecycle
	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
		CUSTOM.z = 0.0;
	}
}

void process() {
	// Gravity
	VELOCITY.y += 800.0 * DELTA;
	
	// Drag
	VELOCITY.x *= 0.95;
	
	// Move
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	
	// Scale over time (shrink)
	// In Godot Particle Shaders, AGE is not a keyword. We use CUSTOM.y or we calculate it.
	// But actually, we have access to CUSTOM which is persistent.
	// Let's store age in CUSTOM.z
	
	CUSTOM.z += DELTA / LIFETIME;
	
	float scale = 1.0 - CUSTOM.z;
	if (scale < 0.0) scale = 0.0;
	
	TRANSFORM[0].x = scale;
	TRANSFORM[1].y = scale;
}

