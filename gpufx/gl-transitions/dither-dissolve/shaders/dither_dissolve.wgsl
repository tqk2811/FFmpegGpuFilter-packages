// Port of DitherDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DitherDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Threshold of the 8x8 Bayer matrix at integer cell c, in (0, 1).
fn bayer(c_in: vec2f) -> f32 {
    var c = c_in;
    var v = 0.0;
    var scale = 16.0;
    for (var i = 0; i < 3; i++) {
        let fc = floor(c);
        let bit = fc - 2.0 * floor(fc / 2.0);
        // A 2x2 step: 0 2 / 3 1, that is 2 * (x xor y) + y.
        v += scale * (2.0 * abs(bit.x - bit.y) + bit.y);
        c *= 0.5;
        scale *= 0.25;
    }
    return (v + 0.5) / 64.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let cell = floor(uv * vec2f(ratio, 1.0) / max(params.dot_size, 1e-4));
    if (progress < bayer(cell)) { return from_color(uv); }
    return to_color(uv);
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
