#version 450

layout(location = 0) out vec2 out_coords;

layout(push_constant) uniform PushConstants {
    vec2 dst_two_over_dims; // rendering target dimensions
    vec2 src_one_over_dims; // rendering src dimensions
    // corners
    vec2 tl; // in screen coordinates, where to draw (dst rect)
    vec2 tr;
    vec2 bl;
    vec2 br;
    vec2 out_tl; // in screen coordinates, where to sample src_image from (src rect)
    vec2 out_tr;
    vec2 out_bl;
    vec2 out_br;
} pc;

void main() {

    const vec2 out_corners[6] = vec2[] (
        pc.out_tl, pc.out_bl, pc.out_tr,
        pc.out_tr, pc.out_bl, pc.out_br 
    );

    vec2 tl = pc.tl * pc.dst_two_over_dims - 1.0;
    vec2 tr = pc.tr * pc.dst_two_over_dims - 1.0;
    vec2 bl = pc.bl * pc.dst_two_over_dims - 1.0;
    vec2 br = pc.br * pc.dst_two_over_dims - 1.0;

    const vec2 corners[6] = vec2[] (
        tl, bl, tr,
        tr, bl, br 
    );

    gl_Position = vec4(corners[gl_VertexIndex], 0.0, 1.0);

    out_coords = out_corners[gl_VertexIndex] * pc.src_one_over_dims;
}