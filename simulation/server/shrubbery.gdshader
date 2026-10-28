shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

group_uniforms Wind_Settings;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.08;
uniform float wind_speed : hint_range(0.0, 10.0) = 2.5;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.5);

group_uniforms Styling;
uniform vec4 base_color : source_color = vec4(0.25, 0.55, 0.2, 1.0);
uniform float color_variation : hint_range(0.0, 1.0) = 0.15;

group_uniforms Backlight_Settings;
uniform vec4 backlight_color : source_color = vec4(0.4, 0.7, 0.2, 1.0);
uniform float backlight_intensity : hint_range(0.0, 1.0) = 0.5;

varying float v_rand_tint;

void vertex() {
	// 1. Extract world position of this specific multimesh instance
	vec3 instance_pos = MODEL_MATRIX[3].xyz;
	
	// Create a pseudo-random phase offset for the wind based on position
	float instance_offset = dot(instance_pos, vec3(12.9898, 78.233, 45.543));
	
	// Generate a unique random tint value (0.0 to 1.0) for this specific instance
	v_rand_tint = fract(sin(dot(instance_pos, vec3(12.98, 78.23, 37.71))) * 43758.5453);
	
	// 2. Vertex Masking: Anchor the base of the leaf/shrub, let the tips sway more.
	float height_mask = max(0.0, VERTEX.y); 
	
	// 3. Wind Wave Math
	float t = (TIME * wind_speed) + instance_offset;
	float wave = sin(t) * 0.7 + sin(t * 2.1) * 0.3; // Layered waves for organic crunchiness
	
	// Apply displacement along the wind direction, scaled by height
	vec3 displacement = normalize(wind_direction) * wave * wind_strength * height_mask;
	VERTEX += displacement;
}

void fragment() {
	// Apply color variation using the tint calculated per-instance in the vertex shader
	vec4 final_color = base_color;
	final_color.rgb += (v_rand_tint - 0.5) * color_variation;
	
	ALBEDO = final_color.rgb;
	ROUGHNESS = 0.9; // Keeps it matte and low-fidelity
	
	// Apply backlighting transmittance for sunlight passing through leaves
	BACKLIGHT = backlight_color.rgb * backlight_intensity;
}