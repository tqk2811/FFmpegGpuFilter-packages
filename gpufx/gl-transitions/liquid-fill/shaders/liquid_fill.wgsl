// Port of LiquidFill.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LiquidFill.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.0015;
const LINE: f32 = 0.006;
const CELL: f32 = 0.08;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Height of the surface above its mean level at x (across the frame, from -1 to 1), between -1
// and 1: a slosh from side to side and a smaller wave running along it.
fn surface(x: f32, t: f32) -> f32 {
    let k = PI * max(params.waves, 0.01);
    return 0.6 * sin(k * x + 0.5 * PI) * cos(2.0 * PI * 1.3 * t)
         + 0.4 * sin(1.7 * k * x - 9.0 * t + 1.3);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = from_color(uv);

    var dir = vec2f(0.0, 1.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let across = vec2f(-dir.y, dir.x);
    // Measured in square pixels, so the waves and bubbles are not stretched.
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let w = 0.5 * (abs(dir.y) * ratio + abs(dir.x));
    let d = dot(p, dir);
    let x = dot(p, across);
    let t = progress;
    let stir = sin(PI * t);
    let amp = max(params.amplitude, 0.0) * (0.35 + 0.65 * stir);
    // The surface starts fully below the frame and ends fully above it, waves and meniscus included.
    let margin = max(params.amplitude, 0.0) + 2.0 * LINE + AA;
    let mean = mix(-e - margin, e + margin, mix(t, t * t * (3.0 - 2.0 * t), 0.5));
    let level = mean + amp * surface(x / w, t);
    // > 0 below the surface, in the liquid.
    let depth = level - d;
    let m = smoothstep(-AA, AA, depth);

    let bend = params.refraction * stir * exp(-max(depth, 0.0) / 0.06);
    let offset = bend * (dir * sin(18.0 * x - 7.0 * t) + across * cos(13.0 * x + 5.0 * t));
    var b = to_color(clamp(uv + offset / vec2f(ratio, 1.0), vec2f(0.0), vec2f(1.0)));

    var glow = 0.0;
    let rise = mean + 0.5 * t;
    let bq = vec2f(x, d - rise) / CELL;
    let cell = floor(bq);
    let hs = hash(cell + 7.1);
    let r = (0.12 + 0.18 * hash(cell + 3.7)) * stir;
    let px = AA / CELL;
    if (hs < params.bubbles * 0.6 && r > px) {
        // Placed so that it stays inside its cell, wobble and soft edge included.
        var c = cell + 0.5 + (0.42 - r - px) * (vec2f(hash(cell + 1.3), hash(cell + 9.4)) * 2.0 - 1.0);
        c.x += 0.08 * sin(6.0 * t + 6.28 * hs);
        let dist = length(bq - c);
        let rim = smoothstep(0.7 * r - px, 0.7 * r + px, dist) * (1.0 - smoothstep(r - px, r + px, dist));
        let glint = 1.0 - smoothstep(0.25 * r - px, 0.25 * r + px, length(bq - c - 0.45 * r * vec2f(-0.7, 0.7)));
        glow = max(rim * 0.6, glint) * smoothstep(0.0, 0.05, depth) * stir;
    }
    var line = 1.0 - smoothstep(LINE - AA, LINE + AA, abs(depth - LINE));
    line += 0.35 * stir * exp(-max(depth, 0.0) / 0.03) * m;
    let light = params.highlight.a * clamp(max(line, glow), 0.0, 1.0) * (0.4 + 0.6 * stir);
    b = vec4f(mix(b.rgb, params.highlight.rgb, light), b.a);

    // Mixed premultiplied, so transparent clips do not bleed their color.
    let c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
    return vec4f(0.0);
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
