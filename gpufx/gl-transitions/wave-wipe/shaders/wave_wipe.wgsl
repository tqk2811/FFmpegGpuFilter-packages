// Port of WaveWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WaveWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// Half width of the antialiased edges, in wave heights.
const AA: f32 = 0.002;
// How far the base of the face trails behind its top, in wave heights.
const TRAIL: f32 = 0.35;
// How far behind the face the water still tints the second clip, in wave heights.
const BAND: f32 = 0.4;
// How far ahead of the lip the spray reaches, in wave heights.
const REACH: f32 = 0.25;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.xyx) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn vnoise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
        mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

// Folds coordinates back into the frame, so a displaced clip never shows its clamped edges.
fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn droplets(q: vec2f, cell: f32, density: f32, seed: f32) -> f32 {
    let g = q / cell;
    let id = floor(g);
    if (hash12(id + seed) >= density) { return 0.0; }
    let r = 0.1 + 0.2 * hash12(id + seed + 4.7);
    let c = id + 0.5 + (0.45 - r) * (vec2f(hash12(id + seed + 1.3), hash12(id + seed + 8.1)) * 2.0 - 1.0);
    let px = AA / cell;
    return 1.0 - smoothstep(r - px, r + px, length(g - c));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let t = progress;
    let ratio = globals.size.x / globals.size.y;
    let fcol = params.foam_color;

    let dir = select(vec2f(1.0, 0.0), normalize(params.direction), length(params.direction) > 0.0);
    // The crest points up the frame, or to the left when the wave travels straight up or down.
    var up = vec2f(-dir.y, dir.x);
    if (up.y < 0.0 || (up.y == 0.0 && up.x > 0.0)) { up = -up; }
    let e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let w = 0.5 * (abs(up.x) * ratio + abs(up.y));
    // In wave heights: u along the travel, v from the trough (0) to the crest (1).
    let p = (uv - 0.5) * vec2f(ratio, 1.0) / (2.0 * w);
    let q = vec2f(dot(p, dir), dot(p, up) + 0.5);
    let ee = e / (2.0 * w);

    let rr = max(params.curl, 0.01);
    // Radius of the hollow at the back of the curl, where it meets the face.
    let rb = 0.5 * rr;
    let tip_angle = PI * (0.08 - 0.5 * smoothstep(0.0, 0.85, t));
    // The wave sweeps from fully ahead of the frame, spray included, to fully past it, tinted water included.
    let travel = mix(t, t * t * (3.0 - 2.0 * t), 0.25);
    let cc = vec2f(mix(-ee - rr - REACH, ee + rb + TRAIL + BAND, travel), 1.02 - rr);

    var d = q - cc;
    // atan is undefined at the very center.
    if (d.x == 0.0) { d.x = 1e-6; }
    let r = length(d);
    let ang = atan2(d.y, d.x);
    // The inner surface of the curl spirals in from the tip of the lip (zero thickness) to the back of the hollow.
    let k = clamp((ang - tip_angle) / (PI - tip_angle), 0.0, 1.0);
    let r_in = rr - (rr - rb) * (1.0 - (1.0 - k) * (1.0 - k));
    let curled = ang >= tip_angle;
    // The face below the curl: vertical where it meets the hollow, its base trailing behind.
    let s = 1.0 - clamp(q.y / cc.y, 0.0, 1.0);
    let face = cc.x - rb - TRAIL * s * s;
    let behind = face - q.x;

    var wet: f32;
    if (curled) {
        wet = smoothstep(-AA, AA, r - r_in) * select(1.0 - smoothstep(-AA, AA, r - rr), 1.0, ang > 0.5 * PI);
    } else {
        wet = smoothstep(-AA, AA, behind);
    }
    let lip = select(0.0, 1.0 - smoothstep(0.5 * PI - 0.3, 0.5 * PI + 0.5, ang), curled);

    let n = vnoise(q * vec2f(14.0, 10.0) + vec2f(-9.0 * t, 3.0 * t));

    var a = from_color(uv);
    let gap = max(min(r - rr, -behind), 0.0);
    var shade = 0.55 * exp(-gap / 0.1) * (1.0 - smoothstep(0.0, REACH, gap)) * smoothstep(0.0, 0.6, q.y) * (1.0 - smoothstep(cc.y + 0.2 * rr, cc.y + 1.1 * rr, q.y));
    shade += 0.25 * (1.0 - smoothstep(0.0, rr, r));
    var argb = a.rgb * (1.0 - shade);
    let fwd = max(r - rr, 0.0);
    let zone = smoothstep(tip_angle - 0.4, tip_angle + 0.2, ang) * (1.0 - smoothstep(0.0, REACH, fwd)) * step(0.0, r - rr);
    let sq = (d - t * vec2f(0.5, -0.25)) * vec2f(0.55, 1.0);
    let thin = exp(-fwd / 0.12);
    let spray = droplets(sq, 0.02, params.foam * thin, 1.0) + 0.6 * droplets(sq * 1.6 + 3.1, 0.02, params.foam * thin, 7.0);
    let mist = params.foam * n * n * exp(-fwd / 0.06) * (1.0 - smoothstep(0.0, REACH, fwd)) * smoothstep(-AA, AA, r - rr) * smoothstep(tip_angle, tip_angle + 0.3, ang);
    argb = mix(argb, fcol.rgb, fcol.a * clamp(spray * zone + mist, 0.0, 1.0));
    a = vec4f(argb, a.a);

    let band = max(1.0 - smoothstep(0.05, BAND, behind), lip);
    let bend = params.refraction * band * band;
    let off = bend * (dir * sin(17.0 * q.y + 2.0 * sin(9.0 * q.x) - 6.0 * t) + up * cos(13.0 * q.x - 5.0 * t));
    var b = to_color(mirror(uv + off * 2.0 * w / vec2f(ratio, 1.0)));
    let luma = dot(b.rgb, vec3f(0.299, 0.587, 0.114));
    let water = params.water;
    var tinted = water.rgb * (0.4 + 0.9 * luma) * (1.0 + 0.6 * q.y);
    tinted += 0.18 * lip * (1.0 - k) * vec3f(0.5, 1.0, 0.9);
    tinted *= 1.0 - 0.35 * lip * (1.0 - smoothstep(0.0, 0.06, r - r_in));
    tinted += 0.35 * select(1.0 - smoothstep(0.0, 0.015, behind), k * (1.0 - smoothstep(0.0, 0.015, r - r_in)), curled) * vec3f(0.7, 0.95, 1.0);
    var brgb = mix(b.rgb, tinted, water.a * band);

    let crest = select(0.0, (1.0 - smoothstep(0.01, 0.02 + 0.12 * n, abs(rr - r))) * smoothstep(tip_angle, tip_angle + 0.4, ang) * (1.0 - smoothstep(0.5 * PI + 0.2, 0.5 * PI + 0.8, ang)), curled);
    let churn = (1.0 - smoothstep(0.0, 0.15 + 0.1 * n, q.y)) * (1.0 - smoothstep(0.0, 0.3, abs(behind))) * smoothstep(0.3, 0.7, n);
    brgb = mix(brgb, fcol.rgb, fcol.a * clamp(params.foam * 1.5 * (crest + churn), 0.0, 1.0));
    b = vec4f(brgb, b.a);

    // Mixed premultiplied, so transparent clips do not bleed their color.
    let c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), wet);
    return select(vec4f(0.0), vec4f(c.rgb / max(c.a, 1e-6), c.a), c.a > 0.0);
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
