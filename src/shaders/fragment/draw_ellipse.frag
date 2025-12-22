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

    vec2 ellipse_radius; // the actual radius of the ellipse, assuming radius.x >= radius.y
    float one_over_radius_y;
    float ratio;
    float one_over_ratio; // ratio = ellipse_radius.x / ellipse_radius.y
    float parabola_peak_x; // (s^2-1)/s; s = ratio
    float parabola_A; // -s^2 / (s^2 - 1)
    float parabola_B; // 2*s
    float parabola_C; // -(s^2 - 1)
    float one_over_two_A; // 0.5 / parabola_A , make sure it's not infinity or something
    
    
    float stroke_radius;
    
} pc;

float parabola(float x) {
    return fma(fma(pc.parabola_A, x, pc.parabola_B), x, pc.parabola_C);
}

vec4 blend(vec4 dst, vec4 src) {
    vec4 src2 = vec4(src.rgb, 1.0);
    return mix(dst, src2, src.a);
}


void main() {

    float sdf;

    if (pc.ellipse_radius.x == pc.ellipse_radius.y) {
        // circle case is much simpler

        float radius = pc.ellipse_radius.x;
        float dist = length(centered_in_coords);

        sdf = dist - radius;

    } else {
        // ellipse case

        vec2 p      = centered_in_coords * pc.one_over_radius_y;
        vec2 radius = pc.ellipse_radius;

        p = abs(p);

        
        float A = pc.parabola_A;
        float B = pc.parabola_B;
        // float C = pc.parabola_C;
        
        // float a = -A;
        float b = 2.0*A*p.x;
        float c = fma(B, p.x, pc.parabola_C - p.y);
        
        float disc = max(0.0, b*b + 4.0*A*c);
        
        float tx = (b + sqrt(disc)) * pc.one_over_two_A;
        tx = clamp(tx, 0.0, pc.parabola_peak_x);
        
        vec2 p1 = vec2(tx * pc.one_over_ratio, parabola(tx));
        vec2 p2 = vec2(p.x * pc.one_over_ratio, p.y);

        vec2 dif = p1 - p2;
        
        float a2 = dot(dif, dif); // can be zero when p2 is at the peak of the parabola
        float b2 = 2 * dot(dif, p2);
        float c2 = dot(p2, p2) - 1.0;
        
        float disc2 = b2*b2 - 4.0*a2*c2; // should be good
        
        float z = (-b2 - sqrt(disc2)) / fma(2.0, a2, 1e-6); 

        // vec2 i = fma(vec2(z,z), dif, p2);
        vec2 i = mix(p2, p1, z);

        float signum = sign(dot(p2, p2) - 1.0);
        
        i.x = i.x * pc.ratio;
        
        sdf = signum * radius.y * distance(i, p);
    
    }

    // sdf = length(centered_in_coords) - pc.stroke_radius;
    
    float fill_alpha   = 1.0 - smoothstep(-0.8, 0.8, sdf);
    float stroke_alpha = 1.0 - smoothstep(-0.8, 0.8, abs(sdf) - pc.stroke_radius);

    vec4 fill_color = vec4(pc.fill_r, pc.fill_g, pc.fill_b, pc.fill_a);
    vec4 stroke_color = vec4(pc.stroke_r, pc.stroke_g, pc.stroke_b, pc.stroke_a);

    fill_color.a *= fill_alpha;
    stroke_color.a *= stroke_alpha; 

    out_color = blend(fill_color, stroke_color);

}