shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms colors;
uniform vec4 shallow_color : source_color = vec4(0.45, 0.82, 0.80, 1.0);
uniform vec4 deep_color    : source_color = vec4(0.16, 0.42, 0.62, 1.0);
uniform vec4 foam_color    : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float depth_falloff = 2.5;      // how quickly shallow -> deep
uniform float color_steps = 4.0;        // posterize the gradient (0 = smooth)
uniform float min_alpha = 0.55;
uniform float max_alpha = 0.95;

group_uniforms foam;
uniform float foam_distance = 0.35;
uniform float foam_wobble = 0.25;
uniform float foam_softness = 0.03;

group_uniforms lines;
uniform float warp_strength = 0.3;
uniform float line_scale = 1.5;
uniform float line_speed = 0.20;
uniform float line_width = 0.03;
uniform float line_strength = 0.15;

group_uniforms waves;
uniform float wave_height = 0.05;
uniform float wave_speed = 0.8;

const float CELL_ORBIT = 0.42;
const float FOAM_NOISE_SCALE = 3.0;

varying vec3 world_pos;
// "random"
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

vec2 cell_point(vec2 cell, float t) {
	vec2 h = hash2(cell);
	vec2 h2 = hash2(cell + 666.0);
	// per-cell speed and phase, so cells drift out of sync and don't look too clunky
	vec2 speed = 0.6 + 0.8 * h2;
	vec2 phase = TAU * h;
	return 0.5 + 0.42 * vec2(sin(t * speed.x + phase.x),
	                         cos(t * speed.y + phase.y));
}

// Distance to the nearest cell border, in cell units
float voronoi_border(vec2 uv, float t) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	// Pass 1: find the closest feature point
	vec2 best_r = vec2(0.0);
	float best_d = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + cell_point(i + g, t) - f;
			float d = dot(r, r);
			if (d < best_d) { best_d = d; best_r = r; }
		}
	}

	// Pass 2: distance to the bisector between the closest point and each neighbor
	float border = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + cell_point(i + g, t) - f;
			vec2 diff = r - best_r;
			if (dot(diff, diff) > 0.00001) {
				border = min(border, dot(0.5 * (best_r + r), normalize(diff)));
			}
		}
	}
	return border;
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

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wp.x * 0.8 + TIME * wave_speed) * cos(wp.z * 0.7 + TIME * wave_speed * 0.8);
	VERTEX.y += w * wave_height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Depth of water column beneath this pixel
	float raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float water_depth = max(-view.z + VERTEX.z, 0.0);

	// Depth gradient that can be stepped if we want
	float t = 1.0 - exp(-water_depth / depth_falloff);
	if (color_steps > 0.5) t = floor(t * color_steps + 0.5) / color_steps;
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, t);
	float alpha = mix(min_alpha, max_alpha, t);

	// Voronoi lines, kinda wind-waker-y
	vec2 p = world_pos.xz * line_scale;
	vec2 warp = vec2(
		value_noise(p * 0.6 + TIME * 0.05),
		value_noise(p * 0.6 + 69.420 - TIME * 0.05)) - 0.5;
	p += warp * warp_strength;

	float edge = voronoi_border(p, TIME * line_speed);

	// Width varies along each line, so it reads as brush strokes, not a grid
	float w = line_width * (0.4 + 1.2 * value_noise(p * 1.7 + TIME * 0.15));

	float aa = max(fwidth(edge), 0.01);
	float lines = 1.0 - smoothstep(w, w + aa, edge);
	col = mix(col, foam_color.rgb, lines * line_strength * (1.0 - t * 0.5));

	// Shoreline foam with a wobbly edge and a hard-ish cutoff
	float wobble = (value_noise(world_pos.xz * 3.0 + TIME * 0.3) - 0.5) * foam_wobble;
	float foam = 1.0 - smoothstep(foam_distance + wobble - foam_softness,
	                              foam_distance + wobble + foam_softness, water_depth);
	col = mix(col, foam_color.rgb, foam);
	alpha = mix(alpha, 1.0, foam);

	ALBEDO = col;
	ALPHA = alpha;
}