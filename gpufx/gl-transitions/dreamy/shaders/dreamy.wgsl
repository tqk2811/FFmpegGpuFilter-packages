// Port of Dreamy.glsl from gl-transitions (author: mikolalysenko, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Dreamy.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn offset(progress: f32, x: f32) -> vec2f {
    return vec2f(0.0, 0.03 * progress * cos(10.0 * (progress + x)));
}

fn transition(p: vec2f, progress: f32) -> vec4f {
    return mix(from_color(p + offset(progress, p.x)), to_color(p + offset(1.0 - progress, p.x)), progress);
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
