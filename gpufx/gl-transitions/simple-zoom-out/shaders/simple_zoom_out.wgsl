// Port of SimpleZoomOut.glsl from gl-transitions (author: Tianshuo, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SimpleZoomOut.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn zoom(uv: vec2f, amount: f32) -> vec2f {
    return 0.5 + (uv - 0.5) * (1.0 - amount);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let q = clamp(params.zoom_quickness, 0.2, 1.0);
    let k = smoothstep(1.0 - q, 1.0, progress);
    let m = select(select(1.0, 0.0, progress < 1.0 - q), k, params.fade != 0u);
    return mix(from_color(uv), to_color(zoom(uv, 1.0 - k)), m);
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
