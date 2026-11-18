// Port of SplitSlideInOutVertical.glsl from gl-transitions (author: OllyOllyOlly, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SplitSlideInOutVertical.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn in_bounds(p: vec2f) -> bool {
    return all(vec2f(0.0) < p) && all(p < vec2f(1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let r = select(1.0, -1.0, params.reverse != 0u);
    let m = select(-1.0, 1.0, uv.x > 0.5) * r;
    let f = vec2f(uv.x, uv.y + progress * m);
    return select(to_color(f - vec2f(0.0, m)), from_color(f), in_bounds(f));
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
