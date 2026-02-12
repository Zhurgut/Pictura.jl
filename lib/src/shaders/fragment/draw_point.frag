#version 450

layout(location = 0) in vec2 in_coords;

layout(location = 0) out vec4 out_color;

layout(push_constant) uniform PushConstants {
    layout(offset = 40) float r;
    float g;
    float b; 
    float a;
    vec2 center; // the center of the point
    float stroke_radius;
} pc;


void main() {

    float sdf = distance(pc.center, in_coords) - pc.stroke_radius;
    
    float a = 1.0 - smoothstep(-0.8, 0.8, sdf);
    
    vec4 stroke_color = vec4(pc.r, pc.g, pc.b, pc.a);
    stroke_color.a *= a; 

    out_color = stroke_color;
}