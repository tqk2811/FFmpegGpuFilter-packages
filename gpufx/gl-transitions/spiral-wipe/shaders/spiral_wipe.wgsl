// Port of SpiralWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpiralWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

// Coverage of the arm turn at position s (in turns along the spiral), d away from its middle line.
fn arm(s_in: f32, d: f32, progress: f32) -> f32 {
    let turns = params.turns;
    // The tip reaches the corners at 60% of the transition, and the arm widens until the end.
    let end = -0.5 + (turns + 0.5) / 0.6;
    let tip = mix(-0.5, end, progress);
    let s = max(s_in, -0.5);
    let width = sqrt(clamp((tip - s) / max(end - s, 0.001), 0.0, 1.0));
    let e = params.smoothness + 0.005 * turns;
    return smoothstep(0.0, e, width * (0.5 + e) - d);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Square pixels, normalized so the corners are at distance 1.
    let q = (uv - 0.5) * vec2f(ratio, 1.0) / (0.5 * length(vec2f(ratio, 1.0)));
    // Fraction of a turn, starting at the top.
    var a = select(atan2(q.x, q.y) / (2.0 * PI), 0.0, dot(q, q) < 1e-12);
    a = fract(select(-a, a, params.clockwise != 0u));
    let w = length(q) * params.turns - a;
    let n = floor(w);
    let f = w - n;
    let m = max(arm(n + a, abs(f - 0.5), progress), max(arm(n + 1.0 + a, 1.5 - f, progress), arm(n - 1.0 + a, f + 0.5, progress)));
    return mix(from_color(uv), to_color(uv), m);
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
