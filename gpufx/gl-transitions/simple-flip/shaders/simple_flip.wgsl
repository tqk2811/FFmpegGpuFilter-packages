// Port of SimpleFlip.glsl from gl-transitions (author: nwoeanhinnogaehr, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SimpleFlip.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(q: vec2f, progress: f32) -> vec4f {
    let h = abs(progress - 0.5);
    let uv = vec2f((q.x - 0.5) / max(h, 1e-6) * 0.5 + 0.5, q.y);
    let a = from_color(uv);
    let b = to_color(uv);
    // `back_color` beside the flipping picture (the original leaves it transparent).
    return mix(params.back_color, mix(a, b, step(0.5, progress)), step(abs(q.x - 0.5), h));
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
