// Port of Comb.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Comb.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let vertical = params.vertical != 0u;
    // a: the axis the strips slide along, b: the axis across them.
    let a = select(uv.x, uv.y, vertical);
    let b = select(uv.y, uv.x, vertical);
    let k = floor(b * f32(max(params.strips, 1)));
    let dir = select(-1.0, 1.0, k - 2.0 * floor(k / 2.0) < 0.5);
    // Ease in and out, but keep moving from the first frame.
    let t = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.6);
    let fa = a - dir * t;
    if (fa >= 0.0 && fa <= 1.0) { return from_color(select(vec2f(fa, b), vec2f(b, fa), vertical)); }
    let ta = fa + dir;
    return to_color(select(vec2f(ta, b), vec2f(b, ta), vertical));
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
