@tool
extends CompositorEffect
class_name PostProcessShader

# This is a compositor effect that can be used as a compositor in godot, created for
# clouds. You can use this file as a template, or modify it directly (assuming you are 
# working on clouds!) 
# Follow the Godot tutorial to get started! It apparently has a test repo to try out as well. 
# https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html#compositor-effects 

# Boilerplate as per tutorial. You will do the rest...
const template_shader: String = """
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	vec4 color = imageLoad(color_image, uv);

	#COMPUTE_CODE

	imageStore(color_image, uv, color);
}
"""
