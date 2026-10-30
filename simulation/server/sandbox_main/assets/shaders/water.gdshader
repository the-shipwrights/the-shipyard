shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// ---------------------------------------------------------------
// Constants
// ---------------------------------------------------------------
const float FOAM_NOISE_SCALE = 3.0;
const float FOAM_NOISE_SPEED = 0.3;

// ---------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------
group_uniforms colors;
uniform vec4 shallow_color : source_color = vec4(0.45, 0.82, 0.80, 1.0);
uniform vec4 deep_color    : source_color = vec4(0.16, 0.42, 0.62, 1.0);
uniform vec4 foam_color    : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float depth_falloff = 2.5;      // how quickly shallow -> deep
uniform float color_steps = 4.0;        // posterize the gradient (0 = smooth)
uniform float band_wobble : hint_range(0.0, 1.0) = 0.15;
uniform float min_alpha = 0.55;
uniform float max_alpha = 0.95;

group_uniforms foam;
uniform float foam_distance = 0.35;
uniform float foam_wobble = 0.25;
uniform float foam_softness = 0.03;

group_uniforms lines;
uniform float line_scale = 1.5;
uniform float line_speed = 0.20;
uniform float warp_strength = 0.3;
uniform float line_depth_fade : hint_range(0.0, 1.0) = 0.5;
uniform float streak_stretch_inv : hint_range(0.05, 1.0) = 0.25; // lower = longer streaks

uniform float light_strength : hint_range(0.0, 1.0) = 0.6;     // how visible the lighter streaks are
uniform float light_lift     : hint_range(0.0, 0.5) = 0.12;    // how much lighter than the water
uniform float light_threshold: hint_range(0.5, 0.95) = 0.74;   // higher = sparser

uniform float dark_strength  : hint_range(0.0, 1.0) = 0.6;
uniform float dark_drop      : hint_range(0.0, 0.5) = 0.14;    // how much darker than the water
uniform float dark_threshold : hint_range(0.5, 0.95) = 0.70;

group_uniforms waves;
uniform float wave_height = 0.05;
uniform float wave_speed = 0.8;

group_uniforms shore_waves;
uniform float shore_influence_dist : hint_range(2.0, 60.0) = 20.0; // how far out waves align to shore
uniform float shore_wave_freq      : hint_range(0.1, 3.0) = 0.9;   // higher = tighter crests
uniform float shore_wave_speed     : hint_range(0.0, 3.0) = 1.2;   // crests travel toward land
uniform float shore_calm_dist      : hint_range(0.1, 10.0) = 2.0;  // waves flatten this close to land

// Set from water_surface.gd
group_uniforms terrain;
uniform sampler2D terrain_height : filter_linear, repeat_disable;
uniform sampler2D shore_dist : filter_linear, repeat_disable;
uniform vec2 terrain_origin;
uniform float cell_size = 1.0;
uniform vec2 terrain_size = vec2(101.0);
uniform float sea_level = 0.0;
uniform float ocean_depth_m = 5.0;
uniform float shore_max_dist = 40.0;

varying vec3 world_pos;

// ---------------------------------------------------------------
// Functions
// ---------------------------------------------------------------

// "random"
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1, 0)).x;
	float c = hash2(i + vec2(0, 1)).x;
	float d = hash2(i + vec2(1, 1)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 terrain_uv(vec2 xz) {
	vec2 grid = (xz - terrain_origin) / cell_size;
	return (grid + 0.5) / terrain_size;
	// +0.5: texels are centered on vertices
}

bool inside_terrain(vec2 xz) {
	vec2 grid = (xz - terrain_origin) / cell_size;
	return all(greaterThanEqual(grid, vec2(0.0)))
		&& all(lessThanEqual(grid, terrain_size - vec2(1.0)));
}

// Vertical water depth from the heightmap
float terrain_depth_at(vec2 xz) {
	if (!inside_terrain(xz)) return ocean_depth_m;
	return max(sea_level - textureLod(terrain_height, terrain_uv(xz), 0.0).r, 0.0);
}

// Distance to nearest land in meters (capped at shore_max_dist)
float shore_dist_at(vec2 xz) {
	if (!inside_terrain(xz)) return shore_max_dist;
	return textureLod(shore_dist, terrain_uv(xz), 0.0).r;
}

// One layer of stretched, warped, thresholded noise. Returns 0..1 mask.
float streak_layer(vec2 xz, vec2 dir, float stretch_inv, float scale,
                   float speed, float warp, float threshold, vec2 offset) {
	vec2 side = vec2(-dir.y, dir.x);
	vec2 q = vec2(dot(xz, dir), dot(xz, side)) + offset;
	q = vec2(q.x * stretch_inv, q.y) * scale;   // stretch along dir
	q.x -= TIME * speed;                         // drift along dir

	// warp so streaks wiggle instead of running ruler-straight
	q += (vec2(value_noise(q * 0.7), value_noise(q * 0.7 + 9.1)) - 0.5) * warp;

	float n = value_noise(q) * 0.65 + value_noise(q * 2.3 + 4.0) * 0.35;
	float aa = max(fwidth(n), 0.01);
	return smoothstep(threshold, threshold + aa, n);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Open-ocean swell: one direction, ignores terrain
	float swell = sin(wp.x * 0.8 + TIME * wave_speed) * cos(wp.z * 0.7 + TIME * wave_speed * 0.8);

	// Near land: crests follow contours of distance-to-shore, travelling toward it
	float d = shore_dist_at(wp.xz);
	float shore_wave = sin(d * shore_wave_freq + TIME * shore_wave_speed);

	float influence = 1.0 - smoothstep(0.0, shore_influence_dist, d);
	float w = mix(swell, shore_wave, influence);

	w *= smoothstep(0.0, shore_calm_dist, d); // flatten right at the coastline
	VERTEX.y += w * wave_height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Water thickness along the view ray (includes boats and anything else in the depth buffer)
	float raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float screen_depth = max(-view.z + VERTEX.z, 0.0);

	// Combine with true vertical depth from the heightmap
	float water_depth = min(screen_depth, terrain_depth_at(world_pos.xz));

	// Depth gradient that can be stepped if we want
	// Slightly wobble depth so band edges aren't perfect contour lines
	float color_depth = water_depth + (value_noise(world_pos.xz * 1.5 + TIME * 0.05) - 0.5) * band_wobble;
	float t = 1.0 - exp(-max(color_depth, 0.0) / depth_falloff);
	if (color_steps > 0.5) {
		float ts = t * color_steps;
		float edge_aa = max(fwidth(ts), 0.001);
		float ramp = smoothstep(0.5 - edge_aa, 0.5 + edge_aa, fract(ts));
		t = (floor(ts) + ramp) / color_steps;
	}
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, t);
	float alpha = mix(min_alpha, max_alpha, t);

		// Two streak layers: same idea, different direction, size, and speed
	float depth_fade = 1.0 - t * line_depth_fade;

	// Darker layer: slightly larger, slower, angled a bit differently
	float dark = streak_layer(world_pos.xz, normalize(vec2(1.0, -0.3)),
	                          streak_stretch_inv * 0.8, line_scale * 0.7,
	                          line_speed * 0.6, warp_strength * 1.3,
	                          dark_threshold, vec2(37.0, 11.0));
	col = mix(col, col * (1.0 - dark_drop), dark * dark_strength * depth_fade);

	// Lighter layer on top
	float light = streak_layer(world_pos.xz, normalize(vec2(1.0, 0.4)),
	                           streak_stretch_inv, line_scale,
	                           line_speed, warp_strength,
	                           light_threshold, vec2(0.0));
	col = mix(col, col + light_lift, light * light_strength * depth_fade);

	// Foam surges in sync with the shore-aligned waves
	float d_shore = shore_dist_at(world_pos.xz);
	float surge = 0.5 + 0.5 * sin(d_shore * shore_wave_freq + TIME * shore_wave_speed);
	float foam_d = foam_distance * (0.6 + 0.8 * surge);

	// Shoreline foam with a wobbly edge and a hard-ish cutoff
	float wobble = (value_noise(world_pos.xz * FOAM_NOISE_SCALE + TIME * FOAM_NOISE_SPEED) - 0.5) * foam_wobble;
	float foam = 1.0 - smoothstep(foam_d + wobble - foam_softness,
	                              foam_d + wobble + foam_softness, water_depth);
	col = mix(col, foam_color.rgb, foam);
	alpha = mix(alpha, 1.0, foam);

	ALBEDO = col;
	ALPHA = alpha;
}
