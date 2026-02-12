#version 450

layout(location = 0) in vec2 in_coords;

layout(location = 0) out vec4 out_color;

layout(push_constant) uniform PushConstants {
    layout(offset = 40) float r;
    float g;
    float b; 
    float a;
    vec2 p1;
    vec2 p2;
    float stroke_radius;
    
} pc;


void main() {

    if (distance(pc.p1, pc.p2) < 0.001) {
        // revert to point case

        float sdf = distance(pc.p1, in_coords) - pc.stroke_radius;
        
        float a = 1.0 - smoothstep(-0.8, 0.8, sdf);
    
        vec4 stroke_color = vec4(pc.r, pc.g, pc.b, pc.a);
        stroke_color.a *= a; 

        out_color = stroke_color;

        return;
    }

    float sdf;

    vec2 l = pc.p2 - pc.p1;

    float delta = dot(in_coords-pc.p1, l) / dot(l, l);

    if (delta <= 0.0) {
        sdf = distance(in_coords, pc.p1);
    } else if (delta >= 1.0) {
        sdf = distance(in_coords, pc.p2);
    } else {
        vec2 projected = pc.p1 + delta * l; // in_coords projected onto line
        sdf = distance(in_coords, projected);
    }

    sdf = sdf - pc.stroke_radius;
    
    float a = 1.0 - smoothstep(-0.8, 0.8, sdf);
    
    vec4 stroke_color = vec4(pc.r, pc.g, pc.b, pc.a);
    stroke_color.a *= a; 

    out_color = stroke_color;
}