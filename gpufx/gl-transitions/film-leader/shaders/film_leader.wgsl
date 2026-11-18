// Port of FilmLeader.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmLeader.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const TAU: f32 = 6.283185307179586;
const AA: f32 = 0.0015;

fn hash11(n0: f32) -> f32 {
    var n = fract(n0 * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn segment(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let pa = p - a;
    let ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Distance to an arc of a circle of center c and radius r, spanning half_angle on both sides of
// the direction mid (radians, counterclockwise from +x).
fn arc(p: vec2f, c: vec2f, r: f32, mid: f32, half_angle: f32) -> f32 {
    var q = p - c;
    let t = PI * 0.5 - mid;
    q = vec2f(q.x * cos(t) - q.y * sin(t), q.x * sin(t) + q.y * cos(t));
    q.x = abs(q.x);
    let sc = vec2f(sin(half_angle), cos(half_angle));
    if (sc.y * q.x > sc.x * q.y) { return length(q - sc * r); }
    return abs(length(q) - r);
}

// Distance to the center line of the strokes of the number n (1 to 5), p within about [-0.6, 0.6] x [-1, 1].
fn numeral(p: vec2f, n: f32) -> f32 {
    let w = 0.14;
    let top = 1.0 - w;
    let bottom = -1.0 + w;
    if (n < 1.5) {
        return min(segment(p, vec2f(0.08, bottom), vec2f(0.08, top)), segment(p, vec2f(0.08, top), vec2f(-0.32, 0.62)));
    }
    if (n < 2.5) {
        var d = arc(p, vec2f(0.0, 0.42), 0.44, 1.05, 1.75);
        d = min(d, segment(p, vec2f(0.337, 0.137), vec2f(-0.46, bottom)));
        return min(d, segment(p, vec2f(-0.46, bottom), vec2f(0.5, bottom)));
    }
    if (n < 3.5) {
        let d = arc(p, vec2f(0.0, 0.47), 0.40, 0.6, 2.35);
        return min(d, arc(p, vec2f(0.0, -0.42), 0.46, -0.6, 2.35));
    }
    if (n < 4.5) {
        var d = segment(p, vec2f(0.26, bottom), vec2f(0.26, top));
        d = min(d, segment(p, vec2f(0.26, top), vec2f(-0.52, -0.36)));
        return min(d, segment(p, vec2f(-0.52, -0.36), vec2f(0.56, -0.36)));
    }
    var d = segment(p, vec2f(-0.36, top), vec2f(0.46, top));
    d = min(d, segment(p, vec2f(-0.36, top), vec2f(-0.40, 0.06)));
    return min(d, arc(p, vec2f(0.0, -0.40), 0.52, -0.09, 2.5));
}

// The countdown frame showing the number n at the point q (centered, scaled to fit the frame),
// where px is the size of one frame height; the tone of the film alternates between numbers.
fn leader_frame(q: vec2f, n: f32, px: f32) -> vec3f {
    let tone = select(1.0, 0.86, n - 2.0 * floor(n / 2.0) < 0.5);
    var c = params.leader_color.rgb * tone;
    let r = length(q);
    let aa = AA * px;
    var ink = 1.0 - smoothstep(0.003 - aa, 0.003 + aa, abs(r - 0.31));
    ink = max(ink, 1.0 - smoothstep(0.0045 - aa, 0.0045 + aa, abs(r - 0.37)));
    ink = max(ink, 1.0 - smoothstep(0.0015 - aa, 0.0015 + aa, min(abs(q.x), abs(q.y))));
    let d = numeral(q / 0.21, n) * 0.21 - 0.031;
    let num = 1.0 - smoothstep(-aa, aa, d);
    let disc = 1.0 - smoothstep(0.31 - 0.003 - aa, 0.31 - 0.003, r);
    ink = max(ink * (1.0 - disc), num);
    c *= 1.0 + 0.06 * disc;
    return mix(c, params.ink_color.rgb, ink * params.ink_color.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let wear = params.wear;
    let ink_color = params.ink_color;
    let fr = from_color(uv);
    let to = to_color(uv);

    let n = clamp(f32(params.count), 1.0, 5.0);
    let sweeps = n + 1.0;
    let ee = progress - 0.35 * sin(TAU * progress) / TAU;
    let t = ee * sweeps;
    let k = min(floor(t), sweeps - 1.0);
    let f = t - k;

    let frame = floor(progress * 12.0 * sweeps);
    let weave = wear * 0.0015;
    let jitter = vec2f(hash11(frame * 1.3 + 0.7) - 0.5, hash11(frame * 2.1 + 5.3) - 0.5) * weave;
    let s = min(ratio, 1.0);
    let p = vec2f((uv.x - 0.5) * ratio, uv.y - 0.5);
    let q = (p + jitter) / s;
    let px = 1.0 / s;

    // The hand, clockwise from 12 o'clock.
    let ha = f * TAU;
    let dir = vec2f(sin(ha), cos(ha));
    let along = dot(p, dir);
    // Signed distance to the hand's line, positive on its trailing side.
    let across = dot(p, vec2f(-dir.y, dir.x));
    // The swept wedge, between the ray at 12 o'clock and the hand: the intersection of the two
    // half planes for half a turn, then their union (signed distance in frame heights, positive
    // inside). It grows by an edge's width at the end of a sweep and shrinks by one at its start,
    // so the antialiased edges never leave a seam when the next sweep starts.
    var d_wedge = select(max(p.x, across), min(p.x, across), f <= 0.5);
    d_wedge += AA * (smoothstep(0.9, 1.0, f) - 1.0 + smoothstep(0.0, 0.1, f));
    let behind = clamp(d_wedge / AA + 0.5, 0.0, 1.0);

    // Before the hand: state k (0 is the first clip), behind it: state k + 1 (sweeps is the second
    // clip); in between, number n - state + 1.
    let ahead = k;
    let swept = k + 1.0;
    let ahead_leader = ahead > 0.5;
    let swept_leader = swept < sweeps - 0.5;
    var ang = 0.0;
    if (dot(p, p) > 0.0) { ang = fract(atan2(p.x, p.y) / TAU + 1.0); }
    let near_center = smoothstep(0.0, 0.05, length(p) / s);
    var ahead_color = fr.rgb;
    var ahead_alpha = fr.a;
    if (behind < 1.0 && ahead_leader) {
        ahead_color = leader_frame(q, n - ahead + 1.0, px) * (1.0 - 0.18 * exp(-(f + 1.0 - ang) * TAU * 2.5) * near_center);
        ahead_alpha = params.leader_color.a;
    }
    var swept_color = to.rgb;
    var swept_alpha = to.a;
    if (behind > 0.0 && swept_leader) {
        swept_color = leader_frame(q, n - swept + 1.0, px) * (1.0 - 0.18 * exp(-max(f - ang, 0.0) * TAU * 2.5) * near_center);
        swept_alpha = params.leader_color.a;
    }
    var c = mix(ahead_color, swept_color, behind);
    var a = mix(ahead_alpha, swept_alpha, behind);
    let on_leader = mix(select(0.0, 1.0, ahead_leader), select(0.0, 1.0, swept_leader), behind);

    let env = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
    let amount = wear * mix(0.35 * env, 1.0, on_leader);
    let cell = floor(uv * vec2f(ratio, 1.0) * 300.0);
    c += (hash12(cell + frame * 37.0) - 0.5) * 0.09 * amount;
    for (var i = 0; i < 4; i++) {
        let fi = f32(i);
        let seg = floor(frame / 3.0);
        let on = step(0.45, hash11(seg * 7.0 + fi * 13.0 + 1.0));
        let x = hash11(fi * 3.7 + 2.0) + 0.04 * (hash11(seg + fi * 5.1) - 0.5);
        let dx = abs(uv.x - x) * ratio;
        let line = 1.0 - smoothstep(0.0, 0.0008 + AA * 0.5, dx);
        let fade = 0.6 + 0.4 * sin(uv.y * (5.0 + fi) + fi * 2.0 + seg);
        c = mix(c, vec3f(1.0), line * on * fade * 0.55 * amount);
    }
    let grid = vec2f(9.0, 6.0);
    let dc = floor(uv * grid);
    let h = hash12(dc + frame * 17.0);
    let center = (dc + 0.2 + 0.6 * vec2f(h, hash12(dc.yx + frame * 11.0 + 3.0))) / grid;
    let speck = 1.0 - smoothstep(0.0015, 0.0015 + AA, length((uv - center) * vec2f(ratio, 1.0)) - 0.002 * h);
    c *= 1.0 - speck * step(0.9, h) * 0.85 * amount;
    var lamp = 1.0 - 0.06 * (hash11(frame + 0.5) - 0.5) * wear;
    lamp *= 1.0 - 0.35 * smoothstep(0.35, 0.95, length(q));
    c *= mix(1.0, lamp, on_leader);

    let hand_on = smoothstep(0.0, 0.03, progress) * (1.0 - smoothstep(0.97, 1.0, progress));
    let hand_w = 0.0022 * s;
    let hand = (1.0 - smoothstep(hand_w - AA, hand_w + AA, abs(across))) * step(0.0, along);
    let shadow = exp(-max(across, 0.0) / (0.012 * s)) * step(0.0, across) * step(0.0, along) * 0.35;
    c *= 1.0 - shadow * hand_on;
    c = mix(c, ink_color.rgb, hand * hand_on * ink_color.a);
    a = mix(a, max(a, ink_color.a), hand * hand_on);
    return vec4f(clamp(c, vec3f(0.0), vec3f(1.0)), a);
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
