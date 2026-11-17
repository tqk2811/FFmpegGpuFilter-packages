// Port of Kaleidoscope.glsl from gl-transitions (author: nwoeanhinnogaehr, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Kaleidoscope.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// GLSL's mod (floored), unlike WGSL's % (truncated).
fn glsl_mod2(x: vec2f, y: f32) -> vec2f { return x - y * floor(x / y); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    var p = uv;
    let q = p;
    var t = pow(progress, params.power) * params.speed;
    p = p - 0.5;
    for (var i = 0; i < 7; i++) {
        p = vec2f(sin(t) * p.x + cos(t) * p.y, sin(t) * p.y - cos(t) * p.x);
        t += params.angle;
        p = abs(glsl_mod2(p, 2.0) - 1.0);
    }
    return mix(
        mix(from_color(q), to_color(q), progress),
        mix(from_color(p), to_color(p), progress),
        1.0 - 2.0 * abs(progress - 0.5));
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
