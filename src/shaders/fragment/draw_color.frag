#version 450

layout(location = 0) out vec4 out_color;

layout(push_constant) uniform PushConstants {
    vec4 background_color; // f32(r, g, b, a)
} pc;

void main() {
    out_color = pc.background_color; 
}