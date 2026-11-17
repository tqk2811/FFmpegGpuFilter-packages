// Port of GlitchMemories.glsl from gl-transitions (author: Gunnar Roth (based on work by natewave), license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchMemories.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(p: vec2f, progress: f32) -> vec4f {
    let block = floor(p / vec2f(16.0));
    var uv_noise = block / vec2f(64.0);
    uv_noise += floor(vec2f(progress) * vec2f(1200.0, 3500.0)) / vec2f(64.0);
    let dist = (fract(uv_noise) - 0.5) * 0.3 * (1.0 - progress) * smoothstep(0.0, 0.05, progress);
    let red = p + dist * 0.2;
    let green = p + dist * 0.3;
    let blue = p + dist * 0.5;
    let center = mix(from_color(green), to_color(green), progress);
    return vec4f(mix(from_color(red), to_color(red), progress).r, center.g, mix(from_color(blue), to_color(blue), progress).b, center.a);
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
