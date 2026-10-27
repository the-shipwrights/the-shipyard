shader_type spatial;

group_uniforms colors;
uniform vec4 deep_color : source_color = vec4(0.08, 0.28, 0.55, 1.0);
uniform vec4 beach_color : source_color = vec4(1.0, 0.72, 0.22, 1.0);
uniform vec4 lowland_color : source_color = vec4(0.20, 0.72, 0.12, 1.0);
uniform vec4 highland_color : source_color = vec4(0.82, 0.54, 0.12, 1.0);
uniform vec4 peak_color : source_color = vec4(0.92, 0.90, 0.82, 1.0);

group_uniforms elevation;
uniform float waterline_start : hint_range(-10.0, 10.0, 0.1) = -1.0;
uniform float waterline_end : hint_range(-10.0, 10.0, 0.1) = 0.5;
uniform float beach_end : hint_range(-10.0, 20.0, 0.1) = 2.5;
uniform float highland_start : hint_range(0.0, 40.0, 0.5) = 16.0;
uniform float highland_end : hint_range(0.0, 50.0, 0.5) = 22.0;
uniform float peak_start : hint_range(0.0, 60.0, 0.5) = 30.0;
uniform float peak_end : hint_range(0.0, 70.0, 0.5) = 36.0;

varying float terrain_height;

void vertex() {
    terrain_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
    vec3 color = deep_color.rgb;

    color = mix(color, beach_color.rgb,
        smoothstep(waterline_start, waterline_end, terrain_height));
    color = mix(color, lowland_color.rgb,
        smoothstep(waterline_end, beach_end, terrain_height));
    color = mix(color, highland_color.rgb,
        smoothstep(highland_start, highland_end, terrain_height));
    color = mix(color, peak_color.rgb,
        smoothstep(peak_start, peak_end, terrain_height));

    ALBEDO = color;
    ROUGHNESS = 1.0;
}