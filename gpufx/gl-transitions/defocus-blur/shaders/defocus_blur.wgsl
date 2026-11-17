// Port of DefocusBlur.glsl from gl-transitions (author: Sergey Kosarevsky, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DefocusBlur.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// 12-tap Poisson disk, https://github.com/spite/Wagner/blob/master/fragment-shaders/poisson-disc-blur-fs.glsl
const TAPS: array<vec2f, 12> = array<vec2f, 12>(
    vec2f(-0.326, -0.406), vec2f(-0.840, -0.074), vec2f(-0.696, 0.457), vec2f(-0.203, 0.621),
    vec2f(0.962, -0.195), vec2f(0.473, -0.480), vec2f(0.519, 0.767), vec2f(0.185, -0.893),
    vec2f(0.507, 0.064), vec2f(0.896, 0.412), vec2f(-0.322, -0.933), vec2f(-0.792, -0.598));

fn transition(uv: vec2f, t: f32) -> vec4f {
    let bs = params.blur_size;
    let d = select(mix(bs, 0.0, (t - 0.5) / 0.5), mix(0.0, bs, t / 0.5), t < 0.5);
    var c0 = from_color(uv);
    var c1 = to_color(uv);
    for (var i = 0; i < 12; i++) {
        c0 += from_color(TAPS[i] * d + uv);
        c1 += to_color(TAPS[i] * d + uv);
    }
    return mix(c0 / 13.0, c1 / 13.0, t);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let uv = gpufx_uv(id);
    // Exact clips at both ends, whatever the formula rounds to.
    if (params.progress <= 0.0) { gpufx_write(id, textureSampleLevel(first, smp, uv, 0.0)); return; }
    if (params.progress >= 1.0) { gpufx_write(id, textureSampleLevel(second, smp, uv, 0.0)); return; }
    gpufx_write(id, transition(vec2f(uv.x, 1.0 - uv.y), params.progress));
}
