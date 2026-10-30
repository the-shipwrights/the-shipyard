shader_type spatial;

render_mode unshaded;

uniform sampler2D image : source_color;
uniform vec3 outline_albedo: source_color;
uniform float border_thickness;

uniform float screen_height;
uniform int particle_count;
uniform vec3[512] particle_positions;
uniform float[512] particle_radiuses;

void vertex() {
		
}

void fragment() {
	ALBEDO = vec3(0.0 , 0.0, 0.0);
	ALPHA = 0.0;
	float screen_width = screen_height * (16.0 / 9.0);
	
	for (int i = 0; i < particle_count; i++) {
		float outline_diameter = border_thickness / (particle_radiuses[i] * 2.0) + 1.0;
		vec4 projection = PROJECTION_MATRIX * VIEW_MATRIX * vec4(particle_positions[i], 1.0);
		projection = projection /= projection.w;
		vec2 screen_uv = vec2(projection.x * 0.5 + 0.5, projection.y * 0.5 + 0.5);
		vec2 screen_uv_diff = SCREEN_UV - screen_uv;
		vec2 screen_radius = vec2(particle_radiuses[i] / screen_width, particle_radiuses[i] / screen_height);
		vec2 scaled_radius = screen_radius * outline_diameter;
		vec4 outline_color;
		if (
			abs(screen_uv_diff.x) < scaled_radius.x + 0.01 &&
			abs(screen_uv_diff.y) < scaled_radius.y + 0.01
		){
			vec2 outline_uv = vec2(
				screen_uv_diff.x * screen_width / (outline_diameter * particle_radiuses[i] * 2.0) + 0.5,
				screen_uv_diff.y * screen_height / (outline_diameter * particle_radiuses[i] * 2.0) + 0.5
			);
			outline_color = texture(image, outline_uv);
		}
		if (
			abs(screen_uv_diff.x) <= scaled_radius.x &&
			abs(screen_uv_diff.y) <= scaled_radius.y
		){
			ALBEDO = outline_albedo;
			ALPHA = 1.0 - (1.0 - ALPHA) * (1.0 - outline_color.a);
		}
	}
	float depth = -100000.0;
	float current_depth = depth;
	vec4 final_color = vec4(0.0);
	
	for (int i = 0; i < particle_count; i++) {
		vec4 view_position = VIEW_MATRIX * vec4(particle_positions[i], 1.0);
		vec4 projection = PROJECTION_MATRIX * view_position;
		projection = projection /= projection.w;
		vec2 screen_uv = vec2(projection.x * 0.5 + 0.5, projection.y * 0.5 + 0.5);
		vec2 screen_uv_diff = SCREEN_UV - screen_uv;
		vec2 screen_radius = vec2(particle_radiuses[i] / screen_width, particle_radiuses[i] / screen_height);
		if (
			abs(screen_uv_diff.x) <= screen_radius.x + 0.01 &&
			abs(screen_uv_diff.y) <= screen_radius.y + 0.01
		){
			float curve_x = pow(screen_uv_diff.x * screen_width, 2);
			float curve_y = pow(screen_uv_diff.y * screen_height, 2);
			float curve = sqrt(pow(particle_radiuses[i], 2) - (curve_x + curve_y));
			float distance_to_camera = view_position.z;
			current_depth = distance_to_camera + curve;
			
			vec2 infill_uv = vec2(
				(SCREEN_UV.x - screen_uv.x) * screen_width / (particle_radiuses[i] * 2.0) + 0.5,
				(SCREEN_UV.y - screen_uv.y) * screen_height / (particle_radiuses[i] * 2.0) + 0.5
			);
			vec4 infill_color = texture(image, infill_uv);
			// infill_color.rgb = vec3(curve, 0.0, 0.0);
			
			if (
				abs(SCREEN_UV.x - screen_uv.x) <= screen_radius.x + 0.01 &&
				abs(SCREEN_UV.y - screen_uv.y) <= screen_radius.y + 0.01
			){
				if (infill_color.a > 0.9999 && current_depth > depth) {
					final_color = infill_color;
					depth = current_depth;
				}
				else if (infill_color.a > 0.0 && current_depth > depth) {
					final_color.rgb = final_color.rgb * (1.0 - infill_color.a) + infill_color.rgb * infill_color.a;
					final_color.a = 1.0 - (1.0 - final_color.a) * (1.0 - infill_color.a);
				}
				else if (infill_color.a > 0.0 && current_depth < depth) {
					final_color.rgb = final_color.rgb * final_color.a + infill_color.rgb * (1.0 - final_color.a);
					final_color.a = 1.0 - (1.0 - final_color.a) * (1.0 - infill_color.a);
				}
			}
		}
	}
	ALBEDO = ALBEDO * (1.0 - final_color.a) + final_color.rgb * final_color.a;
}
