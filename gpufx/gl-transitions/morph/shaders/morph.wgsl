// Port of Morph.glsl from gl-transitions (author: paniq, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Morph.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(p: vec2f, progress: f32) -> vec4f {
    let ca = from_color(p);
    let cb = to_color(p);
    let oa = ((ca.rg + ca.b) * 0.5) * 2.0 - 1.0;
    let ob = ((cb.rg + cb.b) * 0.5) * 2.0 - 1.0;
    let oc = mix(oa, ob, 0.5) * params.strength;
    let w0 = progress;
    let w1 = 1.0 - w0;
    return mix(from_color(p + oc * w0), to_color(p - oc * w1), progress);
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
