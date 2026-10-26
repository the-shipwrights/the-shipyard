shader_type spatial;

render_mode unshaded;

uniform sampler2D image : source_color;
uniform float border_thickness;

uniform int particle_count;
uniform vec3[256] particle_positions;
uniform float[256] particle_radiuses;

void vertex() {
	VERTEX *= border_thickness + 1.0;
}

void fragment() {
	ivec2 imageSize = textureSize(image, 0);

	vec2 pos_pixel = UV;
	vec4 color = texture(image, pos_pixel);
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

	/*
	for (int i = 0; i < 1; i++) {
		vec4 projection = PROJECTION_MATRIX * VIEW_MATRIX * vec4(particle_positions[i], 1.0);
		projection = projection /= projection.w;
		vec2 screen_pos = vec2(projection.x * 0.5 + 0.5, projection.y * -0.5 + 0.5);
		float screen_radius = particle_radiuses[i] * mult;
		ALBEDO = vec3(screen_pos, screen_radius);
	}
	*/
}

void outline() {

}
