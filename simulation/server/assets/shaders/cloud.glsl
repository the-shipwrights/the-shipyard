#[compute]
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

void main() {
    /*ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    vec4 color = imageLoad(color_image, uv);
    vec3 grayscale = vec3(color.r + color.g + color.b) / 3.0;

    imageStore(color_image, uv, vec4(grayscale, 1.0));*/
}