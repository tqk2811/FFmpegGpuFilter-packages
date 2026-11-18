// Port of TopBottom.glsl from gl-transitions (author: zhmy, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TopBottom.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn in_bounds(p: vec2f) -> bool {
    return all(vec2f(0.0) < p) && all(p < vec2f(1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let size = mix(1.0, 3.0, progress * 0.2);
    let spto = (uv - 0.5) * size + 0.5;
    let spfr = uv + vec2f(0.0, 1.0 - progress);
    if (in_bounds(spfr)) { return to_color(spfr); }
    if (in_bounds(spto)) { return from_color(spto) * (1.0 - progress); }
    // Where no picture is drawn: transparent.
    return vec4f(0.0);
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
