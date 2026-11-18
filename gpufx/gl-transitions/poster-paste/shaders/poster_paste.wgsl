// Port of PosterPaste.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PosterPaste.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;
// Length of the bend of a loose sheet just below its pasted part, in frame heights.
const ARC: f32 = 0.18;
// The last sheet is brushed on at this progress, then the paste dries until the end.
const END: f32 = 0.86;
// Each sheet starts this share of a sheet's duration after the previous one.
const STAGGER: f32 = 0.45;
// Share of a sheet's duration spent unfolding its top onto the wall, before the brush.
const UNFOLD: f32 = 0.22;
// Length of paper hanging unfolded below the brush, in frame heights; the rest is still folded up behind it.
const FLAP: f32 = 0.34;
// How far a sheet overlaps the previous one, in frame widths.
const OVERLAP: f32 = 0.006;
// Strength of the perspective: how much nearer things grow, per frame height of distance from the wall.
const PERSPECTIVE: f32 = 1.2;
// Direction towards the light: from the upper left, in front of the wall.
const LIGHT: vec3f = vec3f(-0.25, 0.5, 0.83);
const RELIEF: f32 = 2.5;

var<private> g_progress: f32;
var<private> g_ratio: f32;

fn pp_hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn pp_noise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(pp_hash(i), pp_hash(i + vec2f(1.0, 0.0)), f.x),
        mix(pp_hash(i + vec2f(0.0, 1.0)), pp_hash(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

fn pp_fold(p: vec2f) -> vec2f {
    let m = p - 2.0 * floor(p / 2.0);
    return 1.0 - abs(1.0 - m);
}

// State of sheet k out of n: x = height of the brushed edge in the middle of the sheet, y = how much
// higher that edge is at the sides of the sheet (the brush works from the middle outwards), z = angle
// at which the loose paper leaves the wall, w = its unfolded length.
fn pp_sheet(k: f32, n: f32) -> vec4f {
    let dur = END / (1.0 + (n - 1.0) * STAGGER);
    let t = (g_progress - k * STAGGER * dur) / dur;
    var a = clamp(t / UNFOLD, 0.0, 1.0);
    a = a * a * (3.0 - 2.0 * a);
    let b = max((t - UNFOLD) / (1.0 - UNFOLD), 0.0);
    let f = select(b - 0.1, b * b * 2.5, b < 0.2);
    let front = 1.0 + 2.0 * AA - f * 1.12 / 0.9;
    let theta = mix(1.35, 0.6, a) - 0.15 * smoothstep(0.0, 0.4, b) + 0.1 * sin(b * 10.0) * (1.0 - smoothstep(0.0, 0.6, b));
    return vec4f(front, 0.035 * a, theta, FLAP * a);
}

fn pp_wrinkle(q: vec2f, k: f32) -> f32 {
    let a = 1.0 - abs(2.0 * pp_noise(q * vec2f(12.0, 2.5) + vec2f(k * 13.1, k * 5.7)) - 1.0);
    let b = pp_noise(q * vec2f(22.0, 6.0) + vec2f(k * 7.3 + 4.0, 2.0));
    return 0.004 * a * a + 0.0015 * b;
}

// Relief of the wet paper of sheet k at q (aspect-corrected, on the sheet laid flat): returns its
// slope. Wrinkles flatten with `fresh`; bubbles swell where the brush has just passed, then are pushed flat.
fn pp_relief(q: vec2f, k: f32, fresh: f32, st: vec4f, x0: f32, x1: f32) -> vec2f {
    let h0 = pp_wrinkle(q, k);
    var g = vec2f(pp_wrinkle(q + vec2f(0.002, 0.0), k) - h0, pp_wrinkle(q + vec2f(0.0, 0.002), k) - h0) * (fresh / 0.002);
    for (var j = 0; j < 3; j++) {
        let fj = f32(j);
        let h = vec4f(pp_hash(vec2f(k, fj)), pp_hash(vec2f(fj, k + 11.0)), pp_hash(vec2f(k + 5.0, fj + 3.0)), pp_hash(vec2f(fj + 7.0, k + 2.0)));
        let c = vec2f(mix(x0, x1, 0.2 + 0.6 * h.z) * g_ratio, 0.12 + 0.76 * h.w);
        let e = 0.6 * (2.0 * h.z - 1.0);
        let past = c.y - st.x - st.y * e * e;
        let swell = smoothstep(0.0, 0.08, past) * (1.0 - smoothstep(0.1, 0.55, past));
        let r = (0.03 + 0.03 * h.x) * (0.55 + 0.45 * swell);
        let v = q - c;
        let u = max(1.0 - dot(v, v) / (r * r), 0.0);
        // Height 0.12 r (1 - |v|^2/r^2)^2.
        g -= v * (0.48 / r) * u * swell * step(0.5, h.y + 0.25 * fj);
    }
    return g;
}

// The loose paper of a sheet, hanging from its brushed edge: it leaves the wall at angle theta,
// bends down over ARC, then hangs straight down to a fold. Returns (coverage with edges of half
// width w, x and height on the sheet laid flat, distance from the wall).
fn pp_loose(p: vec2f, st: vec4f, x0: f32, x1: f32, xl: f32, xr: f32, w: f32, top_shift: f32) -> vec4f {
    let th = st.z;
    let c = th / ARC;
    let sin_t = sin(th);
    let cos_t = cos(th);
    let d1 = sin_t / c;
    var x = p.x;
    var h = 0.0;
    var d = 0.0;
    var s = 0.0;
    var z = 0.0;
    var y = p.y;
    // The sheet is seen in perspective, from the middle of the frame: find where it is from where it would be on the wall.
    for (var i = 0; i < 3; i++) {
        let e = clamp((x - x0) / (x1 - x0) * 2.0 - 1.0, -1.0, 1.0);
        h = st.x + st.y * e * e;
        d = h - y;
        s = (th - asin(clamp(sin_t - c * clamp(d, 0.0, d1), -1.0, 1.0))) / c + max(d - d1, 0.0) + min(d, 0.0);
        z = (cos(th - c * clamp(s, 0.0, ARC)) - cos_t) / c;
        x = 0.5 + (p.x - 0.5) * (1.0 - PERSPECTIVE * z);
        y = 0.5 + (p.y - 0.5) * (1.0 - PERSPECTIVE * z);
    }
    y = min(h, 1.0) - s;
    let wx = w / g_ratio;
    let cov = smoothstep(-AA, AA, d + top_shift) * smoothstep(-w, w, y) * smoothstep(-w, w, st.w - s) * smoothstep(-wx, wx, x - xl) * smoothstep(-wx, wx, xr - x);
    return vec4f(cov, x, y, z);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    g_ratio = globals.size.x / globals.size.y;
    let ratio = g_ratio;
    let n = floor(clamp(params.sheets, 2.0, 8.0) + 0.5);
    let creases = clamp(params.wrinkles, 0.0, 1.0);
    let wet = 1.0 - smoothstep(END, 1.0, progress);
    let relief = creases * wet;
    let aax = AA / ratio;
    var cover = 0.0; // coverage of the second clip
    var lit = 0.0; // its shading, premultiplied by the coverage
    var wall = 1.0; // shading of the first clip
    var tuv = uv;

    for (var i = 0; i < 8; i++) {
        let k = f32(i);
        if (k >= n) { break; }
        let x0 = k / n;
        let x1 = (k + 1.0) / n;
        let xl = select(x0 - OVERLAP, -1.0, k < 0.5);
        let xr = select(x1, 2.0, k > n - 1.5);
        let st = pp_sheet(k, n);
        let e = clamp((uv.x - x0) / (x1 - x0) * 2.0 - 1.0, -1.0, 1.0);
        let past = uv.y - st.x - st.y * e * e;
        let in_y = smoothstep(-AA, AA, past);
        let cov = in_y * smoothstep(-aax, aax, uv.x - xl) * smoothstep(-aax, aax, xr - uv.x);
        let edge = (uv.x - xl) * ratio;
        let seam = 0.3 * wet * step(0.5, k) * in_y * (1.0 - smoothstep(0.0, 0.005, -edge)) * step(edge, 0.0);
        lit *= 1.0 - seam;
        wall *= 1.0 - seam;
        if (cov <= 0.0) { continue; }
        let fresh = 1.0 - smoothstep(0.0, 0.6, past);
        var g = vec2f(0.0);
        if (relief > 0.0) { g = pp_relief(vec2f(uv.x * ratio, uv.y), k, fresh, st, x0, x1) * relief; }
        var shade = 1.0 - RELIEF * dot(g, LIGHT.xy) / LIGHT.z;
        shade *= (1.0 - 0.08 * fresh * wet) * (1.0 + 0.06 * (1.0 - smoothstep(0.0, 0.2, past)) * wet);
        let overlap = 0.07 * (1.0 - smoothstep(OVERLAP * ratio, OVERLAP * ratio + 0.002, edge));
        let rim = 0.12 * (1.0 - smoothstep(0.0, 0.0025, edge));
        shade *= 1.0 - (overlap - rim) * wet * step(0.5, k);
        tuv = mix(tuv, uv - g * 0.004, cov);
        lit = lit * (1.0 - cov) + shade * cov;
        cover = cover * (1.0 - cov) + cov;
    }

    // Loose sheets in front of the wall, each one further out than the previous.
    for (var i = 0; i < 8; i++) {
        let k = f32(i);
        if (k >= n) { break; }
        let st = pp_sheet(k, n);
        if (st.w <= 0.0 || st.x + st.y < -0.01) { continue; }
        let x0 = k / n;
        let x1 = (k + 1.0) / n;
        let xl = select(x0 - OVERLAP, -1.0, k < 0.5);
        let xr = select(x1, 2.0, k > n - 1.5);
        let top_shift = 2.0 * AA;
        let z_max = ARC * (1.0 - cos(st.z)) / st.z * smoothstep(0.0, ARC, st.w);
        let sh = pp_loose(uv + LIGHT.xy / LIGHT.z * z_max * vec2f(1.0 / ratio, 1.0), st, x0, x1, xl, xr, AA + 0.5 * z_max, top_shift);
        let shadow = 0.5 * sh.x * smoothstep(0.0, 0.04, sh.w);
        lit *= 1.0 - shadow;
        wall *= 1.0 - shadow;
        let l = pp_loose(uv, st, x0, x1, xl, xr, AA, top_shift);
        if (l.x <= 0.0) { continue; }
        let th = acos(clamp(cos(st.z) + l.w * st.z / ARC, -1.0, 1.0));
        var g = vec2f(0.0);
        if (relief > 0.0) { g = pp_relief(vec2f(l.y * ratio, l.z), k, 1.0, st, x0, x1) * relief; }
        let e = clamp((l.y - x0) / (x1 - x0) * 2.0 - 1.0, -1.0, 1.0);
        let s = min(st.x + st.y * e * e, 1.0) - l.z;
        g.x += 0.8 * creases * smoothstep(0.0, 0.3, s) * cos(l.y * n * 12.57 + k * 2.1 + st.z * 4.0);
        let fold = 1.0 - smoothstep(0.0, 0.035, st.w - s);
        let curl = 1.0 - smoothstep(0.0, 0.04, l.z);
        var shade = (LIGHT.y * sin(th) + LIGHT.z * cos(th)) / LIGHT.z;
        shade *= (1.0 - RELIEF * dot(g, LIGHT.xy) / LIGHT.z) * (1.0 - 0.8 * l.w) * (1.0 - 0.08 * wet) * (1.0 - 0.35 * fold * fold) * (1.0 + 0.15 * curl);
        tuv = mix(tuv, vec2f(l.y, l.z) - g * 0.004, l.x);
        lit = lit * (1.0 - l.x) + shade * l.x;
        cover = cover * (1.0 - l.x) + l.x;
    }

    let a = from_color(uv);
    let b = to_color(pp_fold(tuv));
    return vec4f(a.rgb * wall * (1.0 - cover) + b.rgb * lit, mix(a.a, b.a, cover));
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
