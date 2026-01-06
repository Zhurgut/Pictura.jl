#version 450

layout(push_constant) uniform PushConstants {
    vec4 red_weights;
    vec4 grn_weights;
    vec4 blu_weights;
    vec4 max_weights;
    vec4 min_weights;
    vec4 mid_weights; 
    vec3 rdm_weights; // uniform random in [0, 1]
    float seed;
    vec4 offsets;
} pc;


layout(set = 0, binding = 0) uniform sampler2D the_texture;

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 out_color;

const float PHI = 1.61803398874989484820459; // Φ = Golden Ratio 

float gold_noise(in vec2 xy, in float seed) {
return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}

float rand(vec2 uv, float seed) {
    return fract(sin(dot(uv + seed, vec2(12.9898, 78.233))) * 43758.5453123); // double check
}


void main() {

    vec4 color = texture(the_texture, uv);

    float cmax = max(color.r, max(color.g, color.b));
    float cmin = min(color.r, min(color.g, color.b));

    float sat = (cmax > 0) ? (cmax - cmin) / cmax : 1.0;

    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float midtone = 4.0 * luma * (1.0 - luma); //  =1 for midtones luminance=0.5. =0 at total brightness or darkness

    float rdm = rand(uv, pc.seed);
    

    mat4 m1 = mat4(pc.red_weights, pc.grn_weights, pc.blu_weights, pc.max_weights);
    mat4 m2 = mat4(pc.min_weights, pc.mid_weights, vec4(pc.rdm_weights, 0.0), pc.offsets);

    vec4 v1 = vec4(color.rgb, cmax);
    vec4 v2 = vec4(cmin, midtone, rdm, 1.0);

    vec4 result = m1 * v1 + m2 * v2;
    
    out_color = clamp(result, 0.0, 1.0);
    
}