// Port of RectangleCover.glsl from gl-transitions (author: martiniti, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RectangleCover.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The original's black default covers the whole frame at the midpoint; the default color
// here is a near black so that frame still differs from black (see the manifest).
fn transition(uv: vec2f, progress: f32) -> vec4f {
    let s = pow(2.0 * abs(progress - 0.5), 3.0);
    let k = vec2f(abs(1.0 - 2.0 * progress));
    let bl = step(k, uv + 0.25);
    let tr = step(k, 1.25 - uv);
    let dist = bl.x * bl.y * tr.x * tr.y;
    let img = select(to_color(uv), from_color(uv), progress < 0.5);
    return mix(img, params.color, step(s, dist));
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
