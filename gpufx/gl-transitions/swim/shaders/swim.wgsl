// Port of Swim.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Swim.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.003;
const HEAD: f32 = 0.38;
const PEDUNCLE: f32 = 0.8;
const FORK: f32 = 0.17;
const K: f32 = 2.0 * PI * 0.8;

fn wave(u: f32, amp: f32, ph: f32) -> f32 {
    return amp * (0.1 + 0.9 * u * u) * sin(K * u - ph);
}

fn dwave(u: f32, amp: f32, ph: f32) -> f32 {
    return amp * (1.8 * u * sin(K * u - ph) + (0.1 + 0.9 * u * u) * K * cos(K * u - ph));
}

fn ddwave(u: f32, amp: f32, ph: f32) -> f32 {
    let a = K * u - ph;
    return amp * (1.8 * sin(a) + 3.6 * u * K * cos(a) - (0.1 + 0.9 * u * u) * K * K * sin(a));
}

// The tail fin stays straight, continuing the peduncle, so the bent body never folds over itself.
fn centerline(u: f32, amp: f32, ph: f32) -> f32 {
    return wave(clamp(u, -0.1, PEDUNCLE), amp, ph) + dwave(PEDUNCLE, amp, ph) * max(u - PEDUNCLE, 0.0);
}

fn slope(u: f32, amp: f32, ph: f32) -> f32 {
    if (u < -0.1) { return 0.0; }
    return dwave(min(u, PEDUNCLE), amp, ph);
}

fn trunk(u: f32) -> f32 {
    return 1.0 - params.taper * smoothstep(0.3, PEDUNCLE, u);
}

// Outline half width along the body, 1 = the full frame.
fn profile(u: f32, m: f32) -> f32 {
    let h = pow(sin(0.5 * PI * clamp(u / HEAD, 0.0, 1.0)), 0.6);
    let body = trunk(u);
    let fin = mix(1.0 - params.taper, 0.95, smoothstep(PEDUNCLE, 0.97, u));
    let w = select(max(body, fin), h * body, u < PEDUNCLE);
    return mix(1.0, w, m);
}

// Body coordinates of p: (along, across) in short sides of the frame, found by projecting p on the bent centerline.
fn body_coords(p: vec2f, head: f32, len: f32, amp: f32, ph: f32) -> vec2f {
    var u = (p.x - head) / len;
    for (var i = 0; i < 4; i++) {
        let tn = normalize(vec2f(len, slope(u, amp, ph)));
        u += dot(p - vec2f(head + u * len, 0.5 + centerline(u, amp, ph)), tn) / len;
    }
    let tn = normalize(vec2f(len, slope(u, amp, ph)));
    return vec2f(u, dot(p - vec2f(head + u * len, 0.5 + centerline(u, amp, ph)), vec2f(-tn.y, tn.x)));
}

// Approximate signed distance to the fish, in short sides of the frame.
fn fish(b: vec2f, len: f32, hh: f32, m: f32) -> f32 {
    let e = 0.002;
    let hw = hh * profile(b.x, m);
    let dw = clamp(hh * (profile(b.x + e, m) - profile(b.x - e, m)) / (2.0 * e * len), -4.0, 4.0);
    let side = (abs(b.y) - hw) / sqrt(1.0 + dw * dw);
    let tail = len * (1.0 - m * FORK * (1.0 - min(abs(b.y) / max(hw, 1e-3), 1.0)));
    let s = b.x * len;
    return max(max(side, -s), s - tail) - 2.0 * AA * (1.0 - m);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress;
    let tall = ratio < 1.0;
    let lf = select(ratio, 1.0 / ratio, tall);
    let p = select(vec2f(uv.x * lf, uv.y), vec2f((1.0 - uv.y) * lf, uv.x), tall);

    let m = smoothstep(0.0, 0.35, t);
    let len = lf * mix(1.0, 0.6, m);
    let hh = 0.5 * mix(1.0, 0.6, m);
    // A short body bends tighter for the same swing, so near-square frames swing less.
    let amp = params.swing * min(1.0, lf / 1.6) * smoothstep(0.0, 0.6, t);
    let g = t * (0.5 + 0.5 * t);
    let ph = 2.0 * PI * params.beats * g;
    let travel = 0.6 * lf + 0.3 + params.swing;
    // The head draws back into the frame first; each tail beat adds a small surge to the acceleration.
    let head = 0.12 * lf * m * (1.0 - t) - travel * (pow(t, 2.4) + 0.012 * sin(4.0 * PI * params.beats * g) * t * (1.0 - t));

    let b = body_coords(p, head, len, amp, ph);
    let in_body = 1.0 - smoothstep(-AA, AA, fish(b, len, hh, m));

    let u = b.x;
    let hw = hh * profile(u, m);
    let body = hh * mix(1.0, trunk(u), m);
    let src = mirror(vec2f(u, 0.5 + 0.5 * b.y / max(hw, 0.6 * body)));
    var c = from_color(select(src, vec2f(src.y, 1.0 - src.x), tall));

    let tn = normalize(vec2f(len, slope(u, amp, ph)));
    let lat = select(vec2f(-tn.y, tn.x), tn, tall);
    let vn = clamp(b.y / max(body, 1e-3), -1.0, 1.0);
    let fin = smoothstep(PEDUNCLE - 0.05, PEDUNCLE + 0.05, u);
    let nrm = normalize(vec3f(lat * vn * (1.0 - fin), mix(sqrt(1.0 - vn * vn), 1.0, fin)));
    let ld = normalize(vec3f(-0.35, 0.55, 0.75));
    let diff = max(dot(nrm, ld), 0.0) / ld.z;
    let spec = pow(max(dot(reflect(-ld, nrm), vec3f(0.0, 0.0, 1.0)), 0.0), 16.0);
    let k = params.shading * m;
    let curv = ddwave(clamp(u, 0.0, PEDUNCLE), amp, ph) / (len * len);
    // The inside of a bend is creased and darker, the outside stretched and lighter.
    let crease = clamp(0.25 * curv * vn, -1.0, 1.0) * (1.0 - fin);
    c = vec4f(c.rgb * mix(1.0, min(diff, 1.1) * (1.0 - 0.3 * crease), 0.7 * k) + 0.08 * k * spec * c.a, c.a);

    let off = 0.06 * m * select(vec2f(1.0, -1.0), vec2f(1.0, 1.0), tall);
    // The shadow is soft, so moving it in the body frame found for p is close enough.
    let sd = fish(b - vec2f(dot(off, tn) / len, dot(off, vec2f(-tn.y, tn.x))), len, hh, m);
    var bg = to_color(uv);
    bg = vec4f(bg.rgb * (1.0 - 0.5 * k * (1.0 - smoothstep(-0.04, 0.08, sd))), bg.a);

    return mix(bg, c, in_body * (1.0 - 0.15 * m * fin));
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
