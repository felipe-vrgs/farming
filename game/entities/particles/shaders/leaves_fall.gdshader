shader_type particles;

// Falling leaves particle shader for top-down pixel art.
// Simulates a "Stardew Valley" style drift with sway, tumble, and rotation.
// Uses a "ground plane" + fake height (Z).

uniform float spread_amount = 8.0;

// Ground plane (XY) motion
uniform float initial_velocity_min = 2.0;
uniform float initial_velocity_max = 10.0;
uniform float drag = 2.0; // Air resistance on XY plane
uniform float fall_direction_y = 15.0; // Constant drift towards +Y (down screen/towards camera)

// Fake height (Z)
uniform float initial_height_min = 8.0;
uniform float initial_height_max = 16.0;
uniform float gravity = 60.0; // Reduced gravity for floaty leaves
uniform float terminal_velocity = 40.0; // Max fall speed
uniform float bounce_damping = 0.0; // 0 = no bounce (stick to ground)

// Visuals
uniform float scale_min = 0.065;
uniform float scale_max = 0.11;
uniform float pixel_snap = 1.0;

// Sway & Rotate
uniform float sway_frequency = 2.5;
uniform float sway_amplitude = 15.0; // How much it moves side-to-side
uniform float tumble_frequency = 3.0; // How fast it flips (scale X)
uniform float rotation_speed_min = -3.0;
uniform float rotation_speed_max = 3.0;

// Pixel art settings
uniform int rotation_steps = 16; // Quantize to N discrete angles (8 or 16 recommended)
uniform bool discrete_tumble = true; // Use discrete flip instead of smooth cos()

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

	// Scale (Base)
	float sc = mix(scale_min, scale_max, rand_from_seed(seed));

	// Store base scale in VELOCITY.z for retrieval in process()
	// VELOCITY.z is not used for 2D movement in this shader.
	VELOCITY.z = sc;

	// Ground-plane velocity (Explosion/Burst)
	float ang = rand_from_seed(seed) * 6.2831853;
	float spd = mix(initial_velocity_min, initial_velocity_max, rand_from_seed(seed));

	// Bias the initial direction towards +Y (down screen/towards camera)
	// Map angle so it's more likely to be in the lower semicircle (0 to PI).
	// Or just use the fall_direction_y to bias the initial burst.
	// But let's just do a 360 burst, the drag and drift will take over quickly.

	vec2 dir = vec2(cos(ang), sin(ang));
	VELOCITY.xy = dir * spd;

	// CUSTOM Storage:
	// x: current height (fake Z)
	// y: vertical velocity (fake Z velocity)
	// z: age (time alive)
	// w: random phase for sway/tumble/rotation speed factor
	CUSTOM.x = mix(initial_height_min, initial_height_max, rand_from_seed(seed));

	// Small upward pop to simulate "popping" off the tree
	CUSTOM.y = mix(10.0, 30.0, rand_from_seed(seed));

	CUSTOM.z = 0.0;
	CUSTOM.w = rand_from_seed(seed); // Store 0-1 random value

	if (RESTART_VELOCITY) {
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}

void process() {
	// Age
	CUSTOM.z += DELTA / LIFETIME;
	float t = CUSTOM.z;
	float age_sec = t * LIFETIME;

	// Recover random seed from CUSTOM.w?
	// We used CUSTOM.w as a 0-1 random value.
	float rand_val = CUSTOM.w;

	// Fake Z-axis physics (height)
	float h = CUSTOM.x;
	float vz = CUSTOM.y;

	vz -= gravity * DELTA;
	// Terminal velocity for falling
	if (vz < -terminal_velocity) vz = -terminal_velocity;

	float h_new = h + vz * DELTA;

	// Ground collision
	if (h_new <= 0.0) {
		h_new = 0.0;
		if (bounce_damping > 0.0 && abs(vz) > 10.0) {
			vz = -vz * bounce_damping;
		} else {
			vz = 0.0;
			// Stop horizontal movement on ground
			VELOCITY.xy = vec2(0.0);
		}
	}

	CUSTOM.x = h_new;
	CUSTOM.y = vz;

	// Apply visual offset by delta height (top-down: +height moves up on screen (-Y))
	float dh = h_new - h;
	TRANSFORM[3].y -= dh;

	// Drag/Friction on Ground Plane (air resistance)
	// Apply drag primarily when moving fast, but leaves should float.
	if (h_new > 0.1) {
		VELOCITY.xy -= VELOCITY.xy * drag * DELTA;

		// Apply constant drift towards +Y (fall direction) while in air
		VELOCITY.y += fall_direction_y * DELTA;
	} else {
		// Ground friction is high
		VELOCITY.xy -= VELOCITY.xy * 10.0 * DELTA;
	}

	// Sway (Wind/Flutter) - Only when in air
	if (h_new > 0.0) {
		float sway_phase = age_sec * sway_frequency + (rand_val * 6.28);
		// Sway adds force to X velocity (side to side)
		float sway_force = cos(sway_phase) * sway_amplitude;
		VELOCITY.x += sway_force * DELTA;
	}

	// Move (ground plane)
	TRANSFORM[3].xy += VELOCITY.xy * DELTA;

	// Pixel snap
	if (pixel_snap > 0.0) {
		vec2 p = TRANSFORM[3].xy;
		p = floor(p / pixel_snap + vec2(0.5)) * pixel_snap;
		TRANSFORM[3].xy = p;
	}

	// Rotation & Tumble
	float sc = VELOCITY.z; // Retrieve base scale

	// Rotation - quantized to discrete steps for pixel art
	float rot_speed = mix(rotation_speed_min, rotation_speed_max, rand_val);
	float rot_angle = rot_speed * age_sec + (rand_val * 6.28);

	// Quantize rotation to discrete steps (e.g., 16 = 22.5 degree increments)
	if (rotation_steps > 1) {
		float step_size = 6.28318 / float(rotation_steps);
		rot_angle = floor(rot_angle / step_size) * step_size;
	}

	// Tumble (Scale X oscillation) - discrete flip for pixel art
	float tumble = 1.0;
	if (h_new > 0.0) {
		float tumble_phase = age_sec * tumble_frequency + (rand_val * 6.28);
		if (discrete_tumble) {
			// Discrete flip: -1 or 1 based on phase
			tumble = sign(cos(tumble_phase));
			if (tumble == 0.0) tumble = 1.0; // Handle exact zero
		} else {
			// Original smooth tumble
			tumble = cos(tumble_phase);
		}
	}

	float c = cos(rot_angle);
	float s = sin(rot_angle);

	// Construct basis with rotation and tumble
	// X-axis: rotated and tumbled
	TRANSFORM[0].xy = vec2(c, s) * sc * tumble;
	// Y-axis: rotated (perpendicular) and normal scale
	TRANSFORM[1].xy = vec2(-s, c) * sc;

	// Fade out near end of lifetime - dithered for pixel art
	// Use random threshold per particle for staggered disappearance
	uint fade_seed = hash(uint(INDEX) + 12345u);
	float dither_threshold = float(fade_seed % 65536u) / 65535.0;
	// Particles disappear at different times based on their random threshold
	float fade_start = 0.7 + dither_threshold * 0.25; // Range: 0.7 to 0.95
	if (t > fade_start) {
		COLOR.a = 0.0;
	}
}
