shader_type spatial;

uniform sampler2D image : source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ivec2 imageSize = textureSize(image, 0);
	// vec2 pos = vec2(UV.x * float(imageSize.x), UV.y * float(imageSize.y));
	if (UV.x > 0.5) {
		ALPHA = 0.0;
	}
	else {
		vec2 pos = vec2(UV.x, UV.y);
		vec4 rgba = texture(image, pos, 0);
		vec3 srgb = rgba.rgb;
		ALBEDO = srgb;
		ALPHA  = rgba[3];
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
