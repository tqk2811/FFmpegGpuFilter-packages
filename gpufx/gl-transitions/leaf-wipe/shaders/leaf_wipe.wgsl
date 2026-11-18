// Port of LeafWipe.glsl from gl-transitions (author: @Flexi23, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LeafWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    var leaf = (uv - vec2f(0.5)) / 10.0 / max(pow(progress, 3.5), 1e-6);
    leaf.y += 0.35;
    let r = 0.18;
    let o = atan2(leaf.y, leaf.x);
    let shape = 1.0 - length(leaf) + r * (1.0 + sin(o)) * (1.0 + 0.9 * cos(8.0 * o)) * (1.0 + 0.1 * cos(24.0 * o)) * (0.9 + 0.05 * cos(200.0 * o));
    return mix(from_color(uv), to_color(uv), 1.0 - step(shape, 1.0));
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
