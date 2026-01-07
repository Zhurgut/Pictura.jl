#version 450

layout(push_constant) uniform PushConstants {
    mat4 weights; // column major
    vec4 offsets;
} push;


layout(set = 0, binding = 0) uniform sampler2D the_texture;

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 out_color;


void main() {

    vec4 color = texture(the_texture, uv);

    vec4 result = (push.weights * color) + push.offsets;
    
    out_color = clamp(result, 0.0, 1.0);

}