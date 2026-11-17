// Port of ColorWrap.glsl from gl-transitions (author: Yoni Maltsman, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ColorWrap.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    var fc = from_color(uv);
    let to = to_color(uv);
    let c = fc.rgb + vec3f(params.r_strength, params.g_strength, params.b_strength) * progress;
    // The wrap flips bright (or, with negative strengths, dark) channels at once: fade it in over the first frames.
    let wrapped = c - floor(c);
    fc = vec4f(mix(fc.rgb, wrapped, smoothstep(0.0, 0.1, progress)), fc.a);
    return mix(fc, to, progress);
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
