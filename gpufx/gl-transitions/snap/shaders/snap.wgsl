// Port of Snap.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Snap.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const BREAK: f32 = 0.34;
const AA: f32 = 0.002;

fn ratio() -> f32 { return globals.size.x / globals.size.y; }

fn hash(x: f32) -> f32 {
    var n = fract(x * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

fn jag(y: f32, freq: f32, seed: f32) -> f32 {
    let k = y * freq;
    return mix(hash(floor(k) + seed), hash(floor(k) + seed + 1.0), fract(k)) - 0.5;
}

fn crack_x(y: f32) -> f32 {
    return 0.5 * ratio() + params.jaggedness * (jag(y, 7.0, 3.0) + 0.4 * jag(y, 23.0, 41.0));
}

// p is mirrored for the right half, so both halves hinge on their top corner at x = 0.
fn to_piece(p: vec2f, ca: f32, sa: f32, fall: f32, bend: f32) -> vec2f {
    let v = p + vec2f(0.0, fall - 1.0);
    var q = vec2f(ca * v.x - sa * v.y, sa * v.x + ca * v.y) + vec2f(0.0, 1.0);
    q.y += bend * sin(PI * clamp(q.x / ratio(), 0.0, 1.0));
    return q;
}

fn to_crack(q: vec2f, side: f32) -> f32 {
    let c = crack_x(q.y);
    return select(c, ratio() - c, side > 0.0) - q.x;
}

// Outer edges pushed out by one AA width so the halves tile the frame exactly at rest.
fn cover(q: vec2f, e: f32, w: f32) -> f32 {
    let d = min(q, vec2f(ratio(), 1.0) - q);
    return clamp(min(min(d.x, d.y), e) / w + 1.0, 0.0, 1.0);
}

fn shade(q: vec2f, e: f32, side: f32, sa: f32, front: f32, t: f32) -> vec4f {
    let r = ratio();
    let col = from_color(vec2f(select(q.x / r, 1.0 - q.x / r, side > 0.0), q.y));
    let crack = (1.0 - smoothstep(0.0, 0.005, e)) * (1.0 - smoothstep(front - 0.05, front, q.y));
    return vec4f(col.rgb * (1.0 - 0.75 * crack * (1.0 - smoothstep(0.0, 0.08, t))) * (1.0 - 0.3 * sa * smoothstep(0.0, 0.5 * r, q.x)), col.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let r = ratio();
    let p = vec2f(uv.x * r, uv.y);
    let m = vec2f(r - p.x, p.y);
    let load = smoothstep(0.0, BREAK, progress);
    let t = clamp((progress - BREAK) / (1.0 - BREAK), 0.0, 1.0);
    let bend = params.sag * load * (1.0 - smoothstep(0.0, 0.3, t));
    let front = 1.12 * smoothstep(0.12, BREAK, progress) - 0.06;
    let a = 1.1 * t * (0.6 + 0.4 * t);
    let d = max(t - 0.25, 0.0) / 0.75;
    let fall = 1.1 * d * d;
    let ca = cos(a);
    let sa = sin(a);

    let ql = to_piece(p, ca, sa, fall, bend);
    let qr = to_piece(m, ca, sa, fall, bend);
    let el = to_crack(ql, -1.0);
    let er = to_crack(qr, 1.0);
    let cl = cover(ql, el, AA);
    let cr = cover(qr, er, AA);

    let lift = 0.3 * load + 0.7 * smoothstep(0.0, 0.4, t);
    let o = vec2f(0.015, -0.03) * lift;
    let soft = 0.004 + 0.05 * lift;
    let sl = to_piece(p - o, ca, sa, fall, bend);
    let sr = to_piece(m - vec2f(-o.x, o.y), ca, sa, fall, bend);
    let sh = params.shadow.a * lift * max(cover(sl, to_crack(sl, -1.0), soft), cover(sr, to_crack(sr, 1.0), soft));

    var to = to_color(uv);
    let alpha = sh + to.a * (1.0 - sh);
    to = vec4f((params.shadow.rgb * sh + to.rgb * to.a * (1.0 - sh)) / max(alpha, 1e-5), alpha);
    let col = mix(to, shade(ql, el, -1.0, sa, front, t), cl);
    return mix(col, shade(qr, er, 1.0, sa, front, t), cr);
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
