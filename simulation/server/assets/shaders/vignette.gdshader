shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

group_uniforms Vignette_Settings;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Color of the vignette edges
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.6;          // Overall strength of the effect
uniform float inner_radius : hint_range(0.0, 1.0) = 0.3;               // Where the vignette starts fading in
uniform float outer_radius : hint_range(0.0, 1.0) = 0.8;               // Where the vignette reaches full strength

void fragment() {
	// Sample the original screen color behind the canvas item (using SCREEN_UV)
	vec4 pixelColor = texture(screen_texture, SCREEN_UV);
	
	// Calculate distance from the center of the screen
	float dist = length(UV - vec2(0.5, 0.5));
	
	// Create a smooth transition factor from inner to outer radius
	float vignette_factor = smoothstep(inner_radius, outer_radius, dist);
	
	// Mix the original screen color with the vignette color
	pixelColor.rgb = mix(pixelColor.rgb, vignette_color.rgb, vignette_factor * vignette_intensity);
	
	// Output the final modified color
	COLOR = pixelColor;
}