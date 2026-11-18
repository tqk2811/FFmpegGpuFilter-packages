// Port of PaintDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaintDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// A stroke is about 2.5 times longer than wide: its cell is that much longer than high.
const ROW: f32 = 0.4;
// See pd_layer: antialiasing is 0.0025 frame heights, which fits in 0.06 cells when cells are at
// least MIN_SIZE long.
const MIN_SIZE: f32 = 0.042;

var<private> g_progress: f32;
var<private> g_ratio: f32;

fn pd_hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn pd_hash4(p: vec2f) -> vec4f {
    var p4 = fract(vec4f(p.x, p.y, p.x, p.y) * vec4f(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

fn pd_noise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(pd_hash(i), pd_hash(i + vec2f(1.0, 0.0)), f.x),
        mix(pd_hash(i + vec2f(0.0, 1.0)), pd_hash(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

fn pd_fold(p: vec2f) -> vec2f {
    let m = p - 2.0 * floor(p / 2.0);
    return 1.0 - abs(1.0 - m);
}

// Center of the stroke of a cell (row in y) whose row is shifted by `shift`, in cells of its layer.
fn pd_center(cell: vec2f, shift: f32, h: vec4f) -> vec2f {
    return vec2f(cell.x + 0.5 + shift + (h.x - 0.5) * 0.16, cell.y + 0.5 + (h.y - 0.5) * 0.1);
}

fn pd_to_uv(p: vec2f, off: vec2f, size: f32, dir: vec2f) -> vec2f {
    let l = (p - off) * vec2f(size, size * ROW);
    let q = dir * l.x + vec2f(-dir.y, dir.x) * l.y;
    return q / vec2f(g_ratio, 1.0) + 0.5;
}

// The stroke centered at c (in cells of layer k, offset by `off`) seen from p.
// Returns (coverage, relief shading, start time, streaks).
fn pd_stroke(p: vec2f, c: vec2f, cell: vec2f, h: vec4f, size: f32, k: f32, off: vec2f, t0: f32, spread: f32, dur: f32, dry: f32, dir: vec2f) -> vec4f {
    let d = (p - c) * vec2f(1.0, ROW); // in stroke lengths
    let tilt = (h.z - 0.5) * 0.12;
    let a = d.x + tilt * d.y; // along the stroke
    let b = d.y - tilt * d.x - (h.w - 0.5) * 0.12 * a * a; // across it
    let len = 0.66 + 0.1 * h.w;
    let wd = 0.17 + 0.03 * h.z;
    let world = (c - off) * vec2f(size, size * ROW);
    let order = 0.55 * pd_noise(world * 3.0 + k * 5.0) + 0.45 * pd_hash(cell * 1.7 + vec2f(k * 9.0, 3.0));
    let start = t0 + spread * clamp((order - 0.15) / 0.7, 0.0, 1.0); // (order is mostly in 0.15..0.85)
    var s = clamp((g_progress - start) / dur, 0.0, 1.0);
    s = 1.0 - (1.0 - s) * (1.0 - s);
    let seed = h.x * 37.0 + k * 11.0;
    let bw = b / wd; // -1..1 across the core of the stroke
    // Bristle streaks along the stroke (fewer on small strokes, so that they stay a few pixels wide).
    let hairs = clamp(size * 50.0, 3.0, 16.0);
    let br = 0.6 * pd_noise(vec2f(bw * 0.4 * hairs + seed, a * 2.0)) + 0.4 * pd_noise(vec2f(bw * 0.8 * hairs - seed, a * 1.2 + 5.0));
    let aa = 0.0025 / size;
    let u = clamp(a / len, -1.0, 1.0);
    let width = (0.8 + 0.2 * (1.0 - u * u)) * (0.92 + 0.08 * pd_noise(vec2f(a * 6.0, seed))) - 0.1 * br;
    let side = 1.0 - smoothstep(width - aa / wd, width + aa / wd, abs(bw));
    let tail = smoothstep(-aa, aa, a + len - 0.12 * bw * bw);
    let head = mix(-len - 0.1, len + 0.2, s);
    let lay = smoothstep(0.0, 0.25, (head - a) / 0.2 - 0.6 * br);
    let lift = smoothstep(-aa, aa, len + 0.12 * (br - 0.5) - a);
    let fb = pd_noise(vec2f(bw * hairs + seed, a * 0.9 - seed));
    let dryness = dry * smoothstep(0.1, 1.0, u);
    let cover = side * tail * lay * lift * (1.0 - dryness * (1.0 - smoothstep(0.3, 0.6, fb)));
    let ridge = bw * (1.0 - 0.5 * abs(bw)) * 0.8 + (br - 0.5) + 0.7 * (fb - 0.5);
    let facing = dot(vec2f(-dir.y, dir.x), vec2f(-0.6, 0.8));
    return vec4f(cover, -ridge * facing, start, br);
}

// How much stroke x shows through stroke y: hidden by y where y was laid down after it.
fn pd_under(x: vec4f, y: vec4f) -> f32 {
    return select(1.0, 1.0 - y.x, y.z > x.z);
}

fn pd_shade(k: vec4f, s: vec4f, relief: f32) -> vec4f {
    return vec4f(k.rgb * (1.0 + relief * (s.y + 0.5 * (s.w - 0.5))), k.a);
}

// Paints one layer of strokes over `below`, at an angle `th`. Solid layers take the color of the
// second clip under the middle of each stroke, the detail layers lay down the second clip itself
// (`detail`, at this pixel), with less dry gaps.
// Strokes lie in rows along the direction of their layer, each row shifted by its own amount. A
// pixel looks for strokes in the 2 nearest cells of the 2 nearest rows: a stroke never reaches
// further than 1 cell along its row (0.76 + 0.06 at its dry end + 0.06 of antialiasing + 0.02 of
// tilt + 0.08 of jitter = 0.98) nor than 1 row across (0.2 + 0.06 of antialiasing + 0.05 of tilt
// + 0.04 of bend + 0.02 of jitter = 0.37, out of ROW = 0.4).
fn pd_layer(below: vec4f, q: vec2f, size0: f32, k: f32, th: f32, t0: f32, spread: f32, dur: f32, solid: bool, detail: vec4f) -> vec4f {
    let size = max(size0, MIN_SIZE);
    let dir = vec2f(cos(th), sin(th));
    let off = vec2f(k * 0.37, k * 0.61);
    let p = vec2f(dot(q, dir), dot(q, vec2f(-dir.y, dir.x))) / vec2f(size, size * ROW) + off;
    let r = floor(p.y - 0.5);
    let sh0 = pd_hash(vec2f(r, 7.3));
    let sh1 = pd_hash(vec2f(r + 1.0, 7.3));
    let x0 = floor(p.x - sh0 - 0.5);
    let x1 = floor(p.x - sh1 - 0.5);
    let c0 = vec2f(x0, r);
    let c1 = vec2f(x0 + 1.0, r);
    let c2 = vec2f(x1, r + 1.0);
    let c3 = vec2f(x1 + 1.0, r + 1.0);
    let kk = vec2f(k * 41.0, k * 17.0);
    let h0 = pd_hash4(c0 + kk);
    let h1 = pd_hash4(c1 + kk);
    let h2 = pd_hash4(c2 + kk);
    let h3 = pd_hash4(c3 + kk);
    let m0 = pd_center(c0, sh0, h0);
    let m1 = pd_center(c1, sh0, h1);
    let m2 = pd_center(c2, sh1, h2);
    let m3 = pd_center(c3, sh1, h3);
    let dry = select(0.4, 0.85, solid);
    let s0 = pd_stroke(p, m0, c0, h0, size, k, off, t0, spread, dur, dry, dir);
    let s1 = pd_stroke(p, m1, c1, h1, size, k, off, t0, spread, dur, dry, dir);
    let s2 = pd_stroke(p, m2, c2, h2, size, k, off, t0, spread, dur, dry, dir);
    let s3 = pd_stroke(p, m3, c3, h3, size, k, off, t0, spread, dur, dry, dir);
    let v0 = s0.x * pd_under(s0, s1) * pd_under(s0, s2) * pd_under(s0, s3);
    let v1 = s1.x * pd_under(s1, s0) * pd_under(s1, s2) * pd_under(s1, s3);
    let v2 = s2.x * pd_under(s2, s0) * pd_under(s2, s1) * pd_under(s2, s3);
    let v3 = s3.x * pd_under(s3, s0) * pd_under(s3, s1) * pd_under(s3, s2);
    var k0 = detail;
    var k1 = detail;
    var k2 = detail;
    var k3 = detail;
    // Only the strokes that show are sampled.
    if (solid) {
        if (v0 > 0.0) { k0 = to_color(pd_fold(pd_to_uv(m0, off, size, dir))); }
        if (v1 > 0.0) { k1 = to_color(pd_fold(pd_to_uv(m1, off, size, dir))); }
        if (v2 > 0.0) { k2 = to_color(pd_fold(pd_to_uv(m2, off, size, dir))); }
        if (v3 > 0.0) { k3 = to_color(pd_fold(pd_to_uv(m3, off, size, dir))); }
    }
    let relief = params.impasto * select(0.12, 0.18, solid) * (1.0 - smoothstep(0.7, 0.95, g_progress));
    k0 = pd_shade(k0, s0, relief);
    k1 = pd_shade(k1, s1, relief);
    k2 = pd_shade(k2, s2, relief);
    k3 = pd_shade(k3, s3, relief);
    let vis = v0 + v1 + v2 + v3;
    return below * (1.0 - vis) + k0 * v0 + k1 * v1 + k2 * v2 + k3 * v3;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    g_ratio = globals.size.x / globals.size.y;
    let q = (uv - 0.5) * vec2f(g_ratio, 1.0);
    let to = to_color(uv);
    var col = from_color(uv);
    let sz = params.brush_size;
    let th = params.angle * PI / 180.0;
    let x = params.crossing * 0.6;
    col = pd_layer(col, q, sz, 0.0, th, 0.0, 0.3, 0.12, true, to);
    col = pd_layer(col, q, sz * 0.6, 1.0, th + x, 0.2, 0.28, 0.1, true, to);
    col = pd_layer(col, q, sz * 0.36, 2.0, th - x * 0.7, 0.38, 0.26, 0.09, true, to);
    col = pd_layer(col, q, sz * 0.22, 3.0, th + x * 0.4, 0.56, 0.22, 0.08, false, to);
    col = pd_layer(col, q, sz * 0.2, 4.0, th - x * 0.3, 0.68, 0.2, 0.08, false, to);
    col = mix(col, to, smoothstep(0.92, 1.0, progress));
    return clamp(col, vec4f(0.0), vec4f(1.0));
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
