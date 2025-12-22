#version 450

layout(location = 0) in vec2 centered_in_coords;

layout(location = 0) out vec4 out_color;

layout(push_constant) uniform PushConstants {
    layout(offset = 40) 
    float fill_r;
    float fill_g;
    float fill_b; 
    float fill_a;

    float stroke_r;
    float stroke_g;
    float stroke_b; 
    float stroke_a;

    float top; // max(0, h/2 - radius)
    float right; // max(0, w/2 - radius)
    float radius; // radius of rounded corners
    
    
    float stroke_radius;
    
} pc;

vec4 blend(vec4 dst, vec4 src) {
    vec4 src2 = vec4(src.rgb, 1.0);
    return mix(dst, src2, src.a);
}


void main() {

    vec2 p = abs(centered_in_coords);

    bool to_the_right = pc.right <= p.x;
    bool above = pc.top <= p.y;

    int case_var = int(to_the_right) + int(above);

    float dist = 0.0;

    switch (case_var) {
        case 0: { // inside
            dist = max(p.y - pc.top, p.x - pc.right);
            break;
        }
        case 1: { // in the cross pattern, "orthogonally" outside
            dist = above ? (p.y - pc.top) : (p.x - pc.right);
            break;
        }
        case 2: { // in the corner case
            dist = distance(vec2(pc.right, pc.top), p);
            break;
        }
    };

    float sdf = dist - pc.radius;
    
    float fill_alpha   = 1.0 - smoothstep(-0.8, 0.8, sdf);
    float stroke_alpha = 1.0 - smoothstep(-0.8, 0.8, abs(sdf) - pc.stroke_radius);

    vec4 fill_color = vec4(pc.fill_r, pc.fill_g, pc.fill_b, pc.fill_a);
    vec4 stroke_color = vec4(pc.stroke_r, pc.stroke_g, pc.stroke_b, pc.stroke_a);

    fill_color.a *= fill_alpha;
    stroke_color.a *= stroke_alpha; 

    out_color = blend(fill_color, stroke_color);

}