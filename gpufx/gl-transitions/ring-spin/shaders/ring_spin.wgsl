// Port of RingSpin.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RingSpin.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// Part of a ring's time spent overshooting and coming back.
const SETTLE: f32 = 0.2;
// Half width of the gaps between the rings, width of their rims and of the antialiased edges, in frame heights.
const GAP: f32 = 0.0035;
const RIM: f32 = 0.012;
const EDGE: f32 = 0.0015;

fn mirror_uv(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn rotate(v: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * v.x + s * v.y, c * v.y - s * v.x);
}

// The delay between two rings, kept shorter than the time a ring moves so that the motion never pauses.
fn ring_delay(n: f32) -> f32 {
    let m = max(n - 1.0, 1.0);
    return min(clamp(params.stagger, 0.0, 0.8) / m, 0.7 / (1.0 + 0.7 * m));
}

// Local time of ring i: 0 until it starts, 1 once it is locked.
fn ring_time(i: f32, n: f32, progress: f32) -> f32 {
    let d = ring_delay(n);
    if (progress >= 1.0) { return 1.0; }
    return clamp((progress - d * i) / (1.0 - d * (n - 1.0)), 0.0, 1.0);
}

fn activity(i: f32, n: f32, progress: f32) -> f32 {
    let t = ring_time(i, n, progress);
    return smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.88, 1.0, t));
}

// The ring's angle at its time t: it speeds up, reaches `total` a little fast, overshoots and springs back.
fn spin(t: f32, total: f32) -> f32 {
    let amp = 0.1 * params.settle * sign(total);
    let stop_t = 1.0 - SETTLE;
    // Speed at the stop, matched with the start of the overshoot.
    let v1 = amp * PI * stop_t / (total * SETTLE);
    let u = clamp(t / stop_t, 0.0, 1.0);
    let b = clamp((t - stop_t) / SETTLE, 0.0, 1.0);
    return total * (u * u * (3.0 - 2.0 * u) + v1 * (u * u * u - u * u)) + amp * sin(PI * b) * (1.0 - b) * (1.0 - b);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let square = params.square != 0u;
    let aspect = vec2f(ratio, 1.0);
    let c = (uv - 0.5) * aspect;
    let r = select(length(c), max(abs(c.x), abs(c.y)), square);
    let n = clamp(f32(params.rings), 1.0, 12.0);
    let w = select(length(0.5 * aspect), 0.5 * max(ratio, 1.0), square) / n;
    let f = r / w;
    let i = min(floor(f), n - 1.0);
    let t = ring_time(i, n, progress);

    var col: vec4f;
    if (t <= 0.0) {
        col = from_color(uv);
    } else if (t >= 1.0) {
        col = to_color(uv);
    } else {
        let total = 2.0 * PI * max(f32(params.turns), 1.0) * select(-1.0, 1.0, i - 2.0 * floor(i / 2.0) < 0.5);
        let a = spin(t, total);
        // Angular speed per unit of progress, without the small overshoot; the blur spans what the
        // ring travels in about a frame, at most a short arc so that the 8 taps stay close together.
        let u = min(t / (1.0 - SETTLE), 1.0);
        let omega = abs(total) * 6.0 * u * (1.0 - u) / ((1.0 - SETTLE) * (1.0 - ring_delay(n) * (n - 1.0)));
        let span = params.blur * min(omega * 0.015, 0.1 / max(r, 0.01));
        // The second clip takes over at full speed, hidden by the blur; the whole turns bring it back upright.
        let m = smoothstep(0.3, 0.5, t);
        col = vec4f(0.0);
        var ws = 0.0;
        for (var k = 0; k < 8; k++) {
            let x = f32(k) / 7.0 - 0.5;
            let q = mirror_uv(rotate(c, a + span * x) / aspect + 0.5);
            let s = mix(from_color(q), to_color(q), m);
            col += (1.0 - abs(x)) * s;
            ws += 1.0 - abs(x);
        }
        col /= ws;
    }

    let bj = clamp(floor(f + 0.5), 1.0, max(n - 1.0, 1.0));
    var act = 0.0;
    if (n > 1.5) { act = max(activity(bj - 1.0, n, progress), activity(bj, n, progress)); }
    let d = (f - bj) * w;
    var nr = c / max(r, 1e-4);
    if (square) { nr = select(vec2f(0.0, sign(c.y)), vec2f(sign(c.x), 0.0), abs(c.x) > abs(c.y)); }
    // The outer ring's inner rim faces the center, the inner ring's outer rim faces away from it.
    let light = -sign(d) * dot(nr, vec2f(-0.6, 0.8)) * (1.0 - smoothstep(GAP, GAP + RIM, abs(d))) * act;
    var rgb = col.rgb * (1.0 + 0.45 * light);
    if (light > 0.0) { rgb = mix(col.rgb, vec3f(col.a), 0.35 * light); }
    rgb *= 1.0 - 0.85 * act * (1.0 - smoothstep(GAP - EDGE, GAP + EDGE, abs(d)));
    return vec4f(rgb, col.a);
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
