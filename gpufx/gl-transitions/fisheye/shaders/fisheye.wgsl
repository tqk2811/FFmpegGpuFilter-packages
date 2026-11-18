// Port of Fisheye.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Fisheye.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Lens amount: grows, peaks in the middle, then relaxes, eased so the magnification
    // of the center (1 / (1 - k)) changes at an even pace.
    let h = smoothstep(0.0, 1.0, 1.0 - abs(2.0 * progress - 1.0));
    let k = 1.0 - pow(max(1.0 - params.strength, 0.01), h);
    // Round lens: aspect-corrected coordinates, 1.0 at the corners.
    let aspect = vec2f(ratio, 1.0);
    let c = (uv - 0.5) * aspect;
    let r = length(c) / length(0.5 * aspect);
    // Barrel mapping that keeps the corners in place.
    let q = 0.5 + (uv - 0.5) * (1.0 - k + k * r * r);
    return mix(from_color(q), to_color(q), smoothstep(0.38, 0.62, progress));
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
