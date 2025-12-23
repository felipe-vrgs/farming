shader_type particles;

// Water splash parameters
uniform float spread_amount = 0.8;
uniform float initial_velocity_min = 60.0;
uniform float initial_velocity_max = 90.0;

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
	
	// Random position within a box
	float rx = rand_from_seed(seed) * 2.0 - 1.0;
	float ry = rand_from_seed(seed) * 2.0 - 1.0;
	
	TRANSFORM[3].x = rx * 6.0; // Box width
	TRANSFORM[3].y = ry * 2.0; // Box height
	TRANSFORM[3].z = 0.0;
	
	// Upward velocity with spread
	float angle = (rand_from_seed(seed) - 0.5) * spread_amount; // +/- radians
	// Bias up
	vec3 dir = vec3(sin(angle), -1.0, 0.0);
	dir = normalize(dir);
	
	float speed = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));
	
	VELOCITY = dir * speed;
	
	// Setup custom vars for lifecycle
	CUSTOM.z = 0.0; // Age
	
	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
		CUSTOM.z = 0.0;
	}
}

void process() {
	// Gravity
	VELOCITY.y += 400.0 * DELTA;
	
	// Drag
	VELOCITY.x *= 0.95;
	
	// Move
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	
	// Age
	CUSTOM.z += DELTA / LIFETIME;
	
	// Scale logic (pop in, shrink out)
	float scale = 1.0;
	if (CUSTOM.z < 0.1) {
		scale = CUSTOM.z * 10.0; // Pop in
	} else {
		scale = 1.0 - (CUSTOM.z - 0.1) * 1.1; // Shrink
	}
	if (scale < 0.0) scale = 0.0;
	
	TRANSFORM[0].x = scale;
	TRANSFORM[1].y = scale;
	
	// Color Fade?
	// COLOR.a = scale;
}

