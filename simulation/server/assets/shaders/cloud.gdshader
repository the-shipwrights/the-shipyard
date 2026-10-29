shader_type spatial;

render_mode unshaded;

uniform sampler2D image : source_color;
uniform float border_thickness;

uniform float screen_height;
uniform int particle_count;
uniform vec3[256] particle_positions;
uniform float[256] particle_radiuses;

float get_scale() {
	return 1.0;
}

void vertex() {
	VERTEX *= border_thickness + 1.0;
}

void fragment() {
	/*vec4 color = texture(image, UV);
	ALBEDO = vec3(0.0, 0.0, 0.0);
	ALPHA = color[3];
	
	vec2 scaled_uv = (UV - 0.5) * (border_thickness + 1.0) + 0.5;// / (1.0 + border_thickness/0.5);
	if (
		scaled_uv.x >= 0.0 &&
		scaled_uv.x <= 1.0 &&
		scaled_uv.y >= 0.0 &&
		scaled_uv.y <= 1.0
	){
		vec4 scaled_color = texture(image, scaled_uv);
		ALBEDO += scaled_color.rgb * scaled_color[3];
	}*/

	ALPHA = 0.0;
	float screen_width = screen_height * (16.0 / 9.0);
	float outline_diameter = border_thickness + 1.0;
	
	for (int i = 0; i < 3; i++) {
		vec4 projection = PROJECTION_MATRIX * VIEW_MATRIX * vec4(particle_positions[i], 1.0);
		projection = projection /= projection.w;
		vec2 screen_uv = vec2(projection.x * 0.5 + 0.5, projection.y * 0.5 + 0.5);
		vec2 screen_radius = vec2(particle_radiuses[i] / screen_width, particle_radiuses[i] / screen_height);
		vec2 scaled_radius = screen_radius * outline_diameter;
		if (
			abs(SCREEN_UV.x - screen_uv.x) <= scaled_radius.x  &&
			abs(SCREEN_UV.y - screen_uv.y) <= scaled_radius.y
		){
			vec2 outline_uv = vec2(
				(SCREEN_UV.x - screen_uv.x) * screen_width / outline_diameter + particle_radiuses[i],
				(SCREEN_UV.y - screen_uv.y) * screen_height / outline_diameter + particle_radiuses[i]
			);
			vec4 outline_color = texture(image, outline_uv);
			ALBEDO = vec3(0.0, 0.0, 0.0);
			ALPHA = 1.0 - (1.0 - ALPHA) * (1.0 - outline_color[3]);
		}
	}
	
	float depth = -100000.0;
	float current_depth = depth;
	vec4 final_color = vec4(0.0);
	
	for (int i = 0; i < 3; i++) {
		vec4 view_position = VIEW_MATRIX * vec4(particle_positions[i], 1.0);
		vec4 projection = PROJECTION_MATRIX * view_position;
		projection = projection /= projection.w;
		vec2 screen_uv = vec2(projection.x * 0.5 + 0.5, projection.y * 0.5 + 0.5);
		vec2 screen_radius = vec2(particle_radiuses[i] / screen_width, particle_radiuses[i] / screen_height);
		if (
			abs(SCREEN_UV.x - screen_uv.x) <= screen_radius.x  &&
			abs(SCREEN_UV.y - screen_uv.y) <= screen_radius.y
		){
			float curve_x = sqrt(-pow((SCREEN_UV.x - screen_uv.x) * screen_width, 2) + pow(particle_radiuses[i], 2));
			float curve_y = sqrt(-pow((SCREEN_UV.y - screen_uv.y) * screen_height, 2) + pow(particle_radiuses[i], 2));
			float curve = (curve_x / particle_radiuses[i]) * (curve_y / particle_radiuses[i]) * particle_radiuses[i];
			float distance_to_camera = view_position.z;
			current_depth = distance_to_camera + curve;
			
			vec2 infill_uv = vec2(
				(SCREEN_UV.x - screen_uv.x) * screen_width + particle_radiuses[i],
				(SCREEN_UV.y - screen_uv.y) * screen_height + particle_radiuses[i]
			);
			vec4 infill_color = texture(image, infill_uv);
			if (infill_color[3] == 1.0 && current_depth > depth) {
				final_color = infill_color;
				depth = current_depth;
			}
			else if (infill_color[3] > 0.0 && current_depth > depth) {
				final_color.rgb = final_color.rgb * (1.0 - infill_color[3]) + infill_color.rgb * infill_color[3];
				final_color.a = 1.0 - (1.0 - final_color.a) * (1.0 - infill_color[3]);
			}
			ALBEDO = vec3(-depth / 5.0, 0.0, 0.0);
		}
	}
	// ALBEDO = ALBEDO * (1.0 - final_color.a) + final_color.rgb * final_color.a;
}
