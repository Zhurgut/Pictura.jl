#version 450
layout(location = 0) out vec2 out_coords;

layout(push_constant) uniform PushConstants {
    vec2 two_over_dims; // rendering target dimensions
    // corners
    vec2 tl;
    vec2 tr;
    vec2 bl;
    vec2 br;
} pc;

void main() {

    // we use a triangle list (indices 0, 1, 2, then 3, 4, 5)

    const vec2 raw_corners[6] = vec2[] (
        pc.tl, pc.bl, pc.tr,
        pc.tr, pc.bl, pc.br 
    );

    vec2 tl = pc.tl * pc.two_over_dims - 1 ;
    vec2 tr = pc.tr * pc.two_over_dims - 1 ;
    vec2 bl = pc.bl * pc.two_over_dims - 1 ;
    vec2 br = pc.br * pc.two_over_dims - 1 ;

    const vec2 corners[6] = vec2[] (
        tl, bl, tr,
        tr, bl, br 
    );

    gl_Position = vec4(corners[gl_VertexIndex], 0.0, 1.0);
    out_coords = raw_corners[gl_VertexIndex];
}