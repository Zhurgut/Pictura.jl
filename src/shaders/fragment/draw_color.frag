#version 450

layout(location = 0) out vec4 outColor;

layout(push_constant) uniform PushConstants {
    vec4 backgroundColor; // f32(r, g, b, a)
} pc;

void main() {
    outColor = pc.backgroundColor; 
}