// Port of Vaporize.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Vaporize.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Raggedness of the line where the picture turns to vapour, and the width over which it dissolves.
const RAGGED: f32 = 0.09;
const BAND: f32 = 0.12;
const LIFE: f32 = 0.16;
const TAPS: i32 = 6;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn vnoise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
               mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn fbm(p: vec2f) -> f32 {
    return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.03 + 5.1) + 0.15 * vnoise(p * 4.1 + 9.7);
}

// A swirling flow without sources or sinks: the curl of a noise field.
fn curl(p: vec2f) -> vec2f {
    let e = 0.1;
    let n = vnoise(p);
    let nx = vnoise(p + vec2f(e, 0.0));
    let ny = vnoise(p + vec2f(0.0, e));
    return vec2f(ny - n, n - nx) / e;
}

// Where the line is at time t, as a part of its way across: quicker through the margins outside the frame.
fn sweep(t: f32) -> f32 { return t + 0.6 * t * (1.0 - t) * (1.0 - 2.0 * t); }

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dir = vec2f(0.0, 1.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let side = vec2f(-dir.y, dir.x);
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let along = dot(q, dir);
    let across = dot(q, side);
    let ext = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let ragged = RAGGED * (2.0 * fbm(q * 2.5 + 1.3) - 1.0);
    let start = -ext - RAGGED;
    let travel = 2.0 * ext + 2.0 * RAGGED + BAND;
    let front = start + travel * sweep(progress) + ragged;
    let gone = smoothstep(0.0, BAND, front - along);
    let base = mix(from_color(uv), to_color(uv), gone);
    // The vapour above the line: the higher it is, the longer ago it left the picture.
    let height = max(params.rise, 0.05) * (0.7 + 0.6 * vnoise(vec2f(across * 3.0 + 2.7, 0.5)));
    let age = (along - front) / height;
    let released = progress - age * LIFE;
    if (age <= 0.0 || age >= 1.0 || released <= 0.0) { return base; }
    // Where it came from: the line, back when it was released.
    let origin = start + travel * sweep(released) + ragged;
    let org = q - dir * (along - origin);
    let sw = curl(org * 3.0 + dir * progress * 1.5) * (params.swirl * 0.08 * sqrt(age));
    let src = org - sw;
    let spread_out = (side * 0.07 + dir * 0.02) * sqrt(age);
    var c = vec4f(0.0);
    for (var i = 0; i < TAPS; i++) {
        let t = f32(i) / f32(TAPS - 1) - 0.5;
        let img = from_color(mirror((src + spread_out * t) / vec2f(ratio, 1.0) + 0.5));
        c += vec4f(img.rgb * img.a, img.a);
    }
    if (c.a > 0.0) { c = vec4f(c.rgb / c.a, c.a / f32(TAPS)); } else { c = vec4f(0.0); }
    let wq = (q - 0.6 * sw - dir * (progress * 2.5)) * 4.0;
    let w = fbm(vec2f(dot(wq, side), dot(wq, dir) * 0.6) + 2.0);
    var density = smoothstep(1.2 * age - 0.2, 1.2 * age + 0.1, w);
    density *= 1.0 - smoothstep(0.3, 1.0, age);
    // Only the picture turns to vapour, not what lies beyond its edge.
    density *= smoothstep(-ext, -ext + 0.05, origin);
    let pale = smoothstep(0.0, 0.5, age);
    let l = dot(c.rgb, vec3f(0.299, 0.587, 0.114));
    c = mix(c, vec4f(mix(vec3f(l), params.color.rgb, 0.7), c.a * params.color.a), pale * 0.85);
    c = vec4f(min(c.rgb + 0.12 * pale * density * (1.0 - density), vec3f(1.0)), c.a);
    let a = density * c.a;
    let out_a = a + base.a * (1.0 - a);
    if (out_a <= 0.0) { return vec4f(0.0); }
    return vec4f((c.rgb * a + base.rgb * base.a * (1.0 - a)) / out_a, out_a);
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
