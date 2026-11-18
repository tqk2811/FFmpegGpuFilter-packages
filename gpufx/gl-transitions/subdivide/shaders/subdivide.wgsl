// Port of Subdivide.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Subdivide.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const LEVELS: i32 = 5;
const CUT: f32 = 0.08;
const FLIP: f32 = 0.12;
const CLOSE: f32 = 0.06;
const PERSPECTIVE: f32 = 0.6;

fn hash(n: f32) -> f32 {
    var p = fract(vec3f(n) * vec3f(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

// Ease-out-back so each cut lands with a small kick; then the gap closes with an ease-in.
fn opening(t: f32, l: f32) -> f32 {
    let u = clamp((t - 0.03 - l * 0.07) / CUT, 0.0, 1.0) - 1.0;
    let c = clamp((t - 0.77 - (f32(LEVELS - 1) - l) * 0.04) / CLOSE, 0.0, 1.0);
    return (1.0 + 2.4 * u * u * u + 1.4 * u * u) * (1.0 - c * c);
}

// Columns: (lo.x, lo.y, hi.x), (hi.y, offset.x, offset.y), (coverage, distance to a gap, leaf index).
fn descend(p: vec2f, t: f32, aa: f32, ratio: f32) -> mat3x3f {
    var lo = vec2f(0.0);
    var hi = vec2f(ratio, 1.0);
    var off = vec2f(0.0);
    var node = 1.0;
    var cov = 1.0;
    var edge = 1.0;
    var g = params.gap;
    for (var l = 0; l < LEVELS; l++) {
        let size = hi - lo;
        let ax = select(vec2f(0.0, 1.0), vec2f(1.0, 0.0), size.x > size.y);
        let cut = dot(lo + (0.32 + 0.36 * hash(node)) * size, ax);
        let s = g * opening(t, f32(l));
        let d = dot(p - off, ax) - cut;
        let side = step(0.0, d);
        let dg = abs(d) - 0.5 * s;
        let fade = clamp(s / aa, 0.0, 1.0);
        cov = min(cov, mix(1.0, clamp(0.5 + dg / aa, 0.0, 1.0), fade));
        edge = min(edge, dg + 1.0 - fade);
        off += ax * (side - 0.5) * s;
        lo = mix(lo, lo * (1.0 - ax) + cut * ax, side);
        hi = mix(hi * (1.0 - ax) + cut * ax, hi, side);
        node = 2.0 * node + side;
        g *= 0.8;
    }
    return mat3x3f(vec3f(lo, hi.x), vec3f(hi.y, off), vec3f(cov, edge, node));
}

// A turn in [0, 1]: the leaves flip in the reverse order of the tree.
fn turn(node: f32, t: f32) -> f32 {
    let n = exp2(f32(LEVELS));
    let u = clamp((t - 0.4 - 0.26 * (2.0 * n - 1.0 - node) / (n - 1.0)) / FLIP, 0.0, 1.0);
    return u * u * (3.0 - 2.0 * u);
}

// Card seen at p: (x, y in [-1, 1] on the card, cosine of its turn, coverage).
fn card_point(p: vec2f, m: mat3x3f, t: f32, aa: f32) -> vec4f {
    let lo = m[0].xy;
    let hi = vec2f(m[0].z, m[1].x);
    let hs = 0.5 * (hi - lo);
    let q = p - 0.5 * (lo + hi) - m[1].yz;
    let along_x = hs.x > hs.y;
    let lq = select(q.yx, q, along_x);
    let lh = select(hs.yx, hs, along_x);
    let a = 3.14159265 * turn(m[2].z, t);
    let c = cos(a);
    let s = sin(a);
    // Shrunk by 1 - lh.x * k so its near edge never grows past its own cell.
    let k = PERSPECTIVE * s;
    let m0 = 1.0 - lh.x * k;
    let den = c * m0 - lq.x * k;
    let x = lq.x / select(den, 1e-6, abs(den) < 1e-6);
    let w = (1.0 + x * k) / m0;
    let l = vec2f(x, lq.y * w) / lh;
    let e = (1.0 - abs(l)) * lh * vec2f(abs(c), 1.0) / w;
    // Eased in with the turn so a resting card's edges stay those of its cell.
    let vis = mix(1.0, clamp(0.5 + min(e.x, e.y) / aa, 0.0, 1.0), min(20.0 * s, 1.0));
    return vec4f(select(l.yx, l, along_x), c, vis);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress;
    let p = uv * vec2f(ratio, 1.0);
    let aa = 1.0 / 300.0;
    let m = descend(p, t, aa, ratio);
    let cp = card_point(p, m, t, aa);
    let cov = m[2].x * cp.w;
    let lo = m[0].xy;
    let hi = vec2f(m[0].z, m[1].x);
    let c = 0.5 * (lo + hi);
    let h = 0.5 * (hi - lo);
    let back = cp.z < 0.0;
    var lp = cp.xy;
    if (back) { lp = select(vec2f(cp.x, -cp.y), vec2f(-cp.x, cp.y), h.x > h.y); }
    let src = clamp((c + clamp(lp, vec2f(-1.0), vec2f(1.0)) * h) / vec2f(ratio, 1.0), vec2f(0.0), vec2f(1.0));
    var card = from_color(src);
    if (back) { card = to_color(src); }

    let lift = smoothstep(0.02, 0.18, t) * (1.0 - smoothstep(0.72, 0.99, t));
    let bevel = lift * (1.0 - smoothstep(0.0, 0.005, m[2].y));
    var rgb = mix(card.rgb, card.rgb * 0.7 + 0.3, 0.5 * bevel);
    rgb *= 0.55 + 0.45 * abs(cp.z);
    card = vec4f(rgb, card.a);

    let sp = p + vec2f(-0.012, 0.018) * lift;
    let ms = descend(sp, t, 0.03, ratio);
    let sh = ms[2].x * card_point(sp, ms, t, 0.03).w;
    let bg = vec4f(params.background.rgb * (1.0 - params.shadow * sh * lift), params.background.a);
    return mix(bg, card, cov);
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
