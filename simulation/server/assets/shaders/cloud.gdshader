shader_type spatial;

render_mode unshaded;

uniform sampler2D image : source_color;
uniform float border_thickness;
varying vec3 some_color;

// float new_pos = old_pos * (1 + (border_thickness/width))

void vertex() {
	some_color = VERTEX;
	vec3 new_vertex = VERTEX;

	if (new_vertex.x > 0.0) {
		new_vertex.x += border_thickness;
	}
	else new_vertex.x -= border_thickness;

	if (new_vertex.y > 0.0) {
		new_vertex.y += border_thickness;
	}
	else new_vertex.y -= border_thickness;

	VERTEX = new_vertex;
	// Called for every vertex the material is visible on.
}

void fragment() {
	ivec2 imageSize = textureSize(image, 0);

	vec2 pos_pixel = UV;
	vec4 color = texture(image, pos_pixel);
	ALBEDO = vec3(0.0, 0.0, 0.0);
	// ALBEDO = color.rgb;
	ALPHA = color[3];
	
	vec3 scaled_pos = VERTEX / (1.0 + border_thickness/0.5);
	vec2 scaled_uv = vec2(scaled_pos.x + 0.5, scaled_pos.z + 0.5);
	vec4 scaled_color = texture(image, scaled_uv, 0);
	ALBEDO += scaled_color.rgb * scaled_color[3];
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
