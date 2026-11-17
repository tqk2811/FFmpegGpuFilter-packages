// Port of TvStatic.glsl from gl-transitions (author: Brandon Anzaldi, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvStatic.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// GLSL mod: the result has the sign of y.
fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn noise(co: vec2f, progress: f32) -> f32 {
    let dt = dot(co * progress, vec2f(12.9898, 78.233));
    return fract(sin(gmod(dt, 3.14)) * 43758.5453);
}

fn transition(p: vec2f, progress: f32) -> vec4f {
    if (progress < params.offset) { return from_color(p); }
    if (progress > 1.0 - params.offset) { return to_color(p); }
    // Static where the clips are.
    return vec4f(vec3f(noise(p, progress)), max(from_color(p).a, to_color(p).a));
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
