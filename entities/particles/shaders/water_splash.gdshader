shader_type particles;

// Improved Water Splash parameters
uniform float spread_amount = 0.6;
uniform float initial_velocity_min = 50.0;
uniform float initial_velocity_max = 100.0;
uniform float scale_min = 0.5;
uniform float scale_max = 1.5;

// Colors (Standard uniforms)
uniform vec4 color_a : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.6, 0.9, 1.0, 1.0);

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
	
	// Set Color randomly between the two provided
	COLOR = (rand_from_seed(seed) > 0.5) ? color_a : color_b;
	
	// Position: Horizontal spread, minimal vertical
	float rx = rand_from_seed(seed) * 2.0 - 1.0;
	float ry = rand_from_seed(seed) * 2.0 - 1.0;
	TRANSFORM[3].x = rx * 6.0; 
	TRANSFORM[3].y = ry * 2.0;
	TRANSFORM[3].z = 0.0;
	
	// Velocity: Upwards cone
	float angle = (rand_from_seed(seed) - 0.5) * spread_amount - 1.5708; // Centered on -PI/2 (Up)
	
	float speed = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));
	VELOCITY.x = cos(angle) * speed;
	VELOCITY.y = sin(angle) * speed;
	
	// CUSTOM mapping:
	// z: Age (0 to 1)
	// w: Initial scale
	// y: Random offset for wobble
	CUSTOM.z = 0.0;
	CUSTOM.w = mix(scale_min, scale_max, rand_from_seed(seed));
	CUSTOM.y = rand_from_seed(seed) * 6.28;
	
	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}

void process() {
	// Gravity - Water is heavy
	VELOCITY.y += 800.0 * DELTA;
	
	// Drag
	VELOCITY.x *= 0.98;
	
	// Move
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	
	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;
	
	// Scale logic
	float base_scale = CUSTOM.w;
	
	// Pop in quickly, shrink out slowly
	float scale = base_scale * smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.6, 1.0, t));
	
	// Stretch based on velocity
	float speed = length(VELOCITY);
	float stretch = 1.0 + (speed * 0.003);
	stretch = min(stretch, 2.0); // Cap stretch
	
	// Rotation facing velocity
	float angle = atan(VELOCITY.y, VELOCITY.x) + 1.5708;
	float c = cos(angle);
	float s = sin(angle);
	
	// Apply stretch: Thin on X, Long on Y (relative to rotation)
	vec2 scale_vec = vec2(1.0 / sqrt(stretch), stretch) * scale;
	
	TRANSFORM[0].xy = vec2(c, s) * scale_vec.x;
	TRANSFORM[1].xy = vec2(-s, c) * scale_vec.y;
	
	// Color Fade
	COLOR.a = 1.0 - (t * t * t); // Sharp fade at end
}
