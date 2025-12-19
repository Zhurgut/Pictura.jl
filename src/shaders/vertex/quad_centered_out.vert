#version 450
layout(location = 0) out vec2 centered_out_coords;

layout(push_constant) uniform PushConstants {
    vec2 two_over_dims; // rendering target dimensions
    // corners
    vec2 tl; // in screen coordinates, assuming the ellipse sits at the center of this rectangle
    vec2 tr;
    vec2 bl;
    vec2 br;
} pc;

void main() {

    // we use a triangle list (indices 0, 1, 2, then 3, 4, 5)

    vec2 rect_radius = 0.5 * vec2(distance(pc.tr, pc.tl), distance(pc.bl, pc.tl));

    vec2 ct_tl = -rect_radius;
    vec2 ct_tr = vec2(rect_radius.x, -rect_radius.y);
    vec2 ct_bl = vec2(-rect_radius.x, rect_radius.y);
    vec2 ct_br = rect_radius;
    

    const vec2 centered_corners[6] = vec2[] (
        ct_tl, ct_bl, ct_tr,
        ct_tr, ct_bl, ct_br 
    );

    vec2 tl = pc.tl * pc.two_over_dims - 1.0;
    vec2 tr = pc.tr * pc.two_over_dims - 1.0;
    vec2 bl = pc.bl * pc.two_over_dims - 1.0;
    vec2 br = pc.br * pc.two_over_dims - 1.0;

    const vec2 corners[6] = vec2[] (
        tl, bl, tr,
        tr, bl, br 
    );

    gl_Position = vec4(corners[gl_VertexIndex], 0.0, 1.0);

    centered_out_coords = centered_corners[gl_VertexIndex];
}