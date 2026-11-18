// Port of StaticFade.glsl from gl-transitions (author: Ben Lucas, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StaticFade.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn rnd(st: vec2f) -> f32 {
    return fract(sin(dot(st, vec2f(10.5302340293, 70.23492931))) * 12345.5453123);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let base = mix(from_color(uv), to_color(uv), step(0.5, progress));
    let n = max(params.noise_pixels, 1.0);
    let st = floor(uv * n) / n;
    let l = params.luminosity;
    let o = progress;
    let noise = vec4f(l * rnd(st * vec2f(o * 2.0, o * 3.0)), l * rnd(st * vec2f(o * 3.0, o * 5.0)), l * rnd(st * vec2f(o * 5.0, o * 7.0)), base.a);
    let thresh = min(1.0, 1.2 * (1.0 - abs(2.0 * (progress - 0.5))) - 0.1);
    return mix(base, noise, step(rnd(st), thresh));
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
