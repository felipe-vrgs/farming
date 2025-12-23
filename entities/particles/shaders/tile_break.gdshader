shader_type particles;

// "Dusty" Tile Break shader
// Lots of small particles for a crumbling effect
uniform float spread_amount = 0.4;
uniform float initial_velocity_min = 20.0;
uniform float initial_velocity_max = 40.0;
uniform float scale_min = 0.5;
uniform float scale_max = 1.5;

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
	COLOR = mix(color_a, color_b, color_mix);
	
	// Position: 
	// Distribute randomly within the 16x16 tile, but bias slightly to center
	// to avoid spawning exactly on the grid lines which looks weird.
	float rx = (rand_from_seed(seed) * 14.0 - 7.0);
	float ry = (rand_from_seed(seed) * 14.0 - 7.0);
	TRANSFORM[3].xy = vec2(rx, ry);
	
	// Velocity
	// Radial explosion with upward tendency
	float angle = atan(ry, rx);
	float up_bias = -1.57;
	
	// Mix radial direction with "Up" direction
	angle = mix(angle, up_bias, 0.4);
	// Add randomness
	angle += (rand_from_seed(seed) - 0.5) * 1.5;
	
	float speed = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));
	
	VELOCITY.x = cos(angle) * speed;
	VELOCITY.y = sin(angle) * speed;
	
	// CUSTOM data
	// z: Age
	CUSTOM.z = 0.0;
	
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
	// Gravity
	VELOCITY.y += 500.0 * DELTA;
	
	// Drag
	VELOCITY.x *= 0.94;
	VELOCITY.y *= 0.98;
	
	// Move
	vec3 pos = TRANSFORM[3].xyz;
	pos += VELOCITY * DELTA;
	TRANSFORM[3].xyz = pos;
	
	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;
	
	// Fade/Shrink
	if (t > 0.5) {
		float fade = (t - 0.5) * 2.0;
		COLOR.a = 1.0 - fade;
		
		// Shrink slightly to disappear
		float scale_mod = 1.0 - (fade * 0.5);
		TRANSFORM[0].xy *= scale_mod;
		TRANSFORM[1].xy *= scale_mod;
	}
}
