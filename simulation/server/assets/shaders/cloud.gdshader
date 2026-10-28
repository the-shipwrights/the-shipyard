shader_type spatial;

render_mode unshaded;

uniform sampler2D image : source_color;
uniform float border_thickness;

uniform float screen_height;
uniform int particle_count;
uniform vec3[256] particle_positions;
uniform float[256] particle_radiuses;

varying flat int instance_id;

float get_scale() {
	return 1.0;
}

void vertex() {
	VERTEX *= border_thickness + 1.0;
	instance_id = INSTANCE_ID;
}

void fragment() {
	ivec2 imageSize = textureSize(image, 0);
	ivec2 fragment_pos = ivec2(SCREEN_UV * VIEWPORT_SIZE);

	vec4 color = texture(image, UV);
	ALBEDO = vec3(0.0, 0.0, 0.0);
	ALPHA = color[3];
	
	vec2 scaled_uv = (UV - 0.5) * (border_thickness + 1.0) + 0.5;// / (1.0 + border_thickness/0.5);
	if (
		scaled_uv.x >= 0.0 &&
		scaled_uv.x <= 1.0 &&
		scaled_uv.y >= 0.0 &&
		scaled_uv.y <= 1.0
	) {
		vec4 scaled_color = texture(image, scaled_uv);
		ALBEDO += scaled_color.rgb * scaled_color[3];
	}



	for (int i = 0; i < 1; i++) {
		
		vec4 projection = PROJECTION_MATRIX * VIEW_MATRIX * vec4(particle_positions[i], 1.0);
		projection = projection /= projection.w;
		vec2 screen_uv = vec2(projection.x * 0.5 + 0.5, projection.y * -0.5 + 0.5);
		float scale = 1.0;
		float screen_radius = particle_radiuses[i] / screen_height;
		float pixel_radius = VIEWPORT_SIZE.y * screen_radius;
		ALBEDO = vec3(screen_uv, particle_radiuses[i] / 2.0);
	}
	
	ALBEDO = vec3(float(instance_id) / 2.0, 0.0, 0.0);
}

void outline() {

}
