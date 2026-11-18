// Port of ZoomWipeRight.glsl from gl-transitions (author: Handk, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ZoomWipeRight.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The original holds the unzoomed first clip at exactly the midpoint, where zooming ends and
// wiping starts; here the zoom ends and the wipe starts at 0.45 so no frame stands still.
const SPLIT: f32 = 0.45;

fn zoom(uv: vec2f, amount: f32) -> vec2f {
    if (amount < 0.5) { return 0.5 + (uv - 0.5) * (1.0 - amount); }
    return 0.5 + (uv - 0.5) * amount;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let q = clamp(params.zoom_quickness, 0.01, 0.5) * SPLIT / 0.5;
    if (progress < SPLIT) { return from_color(zoom(uv, smoothstep(0.0, q, progress))); }
    return mix(from_color(uv), to_color(uv), step(uv.x, (progress - SPLIT) / (1.0 - SPLIT)));
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
