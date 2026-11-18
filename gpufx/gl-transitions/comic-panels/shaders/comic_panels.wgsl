// Port of ComicPanels.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ComicPanels.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const INK: f32 = 0.005;
const EDGE: f32 = 0.0012;
const PUNCH: f32 = 0.3;
// The first panel's punch starts at START, the last one ends at END.
const START: f32 = 0.05;
const END: f32 = 0.97;
const SPIKES: f32 = 11.0;

fn ratio() -> f32 { return globals.size.x / globals.size.y; }
fn seed() -> f32 { return f32(params.seed); }

fn hash(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.xyx) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn cols(r: f32) -> f32 {
    let h = hash(vec2f(r * 7.0 + 3.0, seed() * 1.37 + 11.0));
    var n = select(select(3.0, 2.0, h < 0.6), 1.0, h < 0.15);
    // The middle row is never a single panel, a narrow frame takes at most 2 panels per row.
    if (r == 1.0) { n = max(n, 2.0); }
    if (ratio() < 0.8) { n = min(n, 2.0); }
    return n;
}

// Signed distance of p (x from 0 to ratio, y from 0 at the top to 1) below the gutter k between the rows
// (0 is the top of the frame, 3 its bottom).
fn row_dist(k: f32, p: vec2f) -> f32 {
    if (k < 0.5) { return p.y; }
    if (k > 2.5) { return p.y - 1.0; }
    let r = ratio();
    let y = (k + (hash(vec2f(k * 5.0 + 1.0, seed() * 1.37)) - 0.5) * 0.35) / 3.0;
    let s = (hash(vec2f(k * 9.0 + 4.0, seed() * 1.37 + 5.0)) - 0.5) * 0.24;
    return (p.y - y - s * (p.x / r - 0.5)) / sqrt(1.0 + s * s / (r * r));
}

// Signed distance of p right of the gutter j of row r, which has n panels (0 is the left of the frame, n its right).
fn col_dist(r: f32, j: f32, n: f32, p: vec2f) -> f32 {
    let ra = ratio();
    if (j < 0.5) { return p.x; }
    if (j > n - 0.5) { return p.x - ra; }
    let x = (j + (hash(vec2f(r * 3.0 + j * 13.0, seed() * 1.37 + 2.0)) - 0.5) * 0.45) / n;
    let s = (hash(vec2f(r * 11.0 + j * 5.0, seed() * 1.37 + 7.0)) - 0.5) * 0.5;
    return (p.x - ra * (x + s * (p.y - 0.5))) / sqrt(1.0 + ra * ra * s * s);
}

// Signed distance to the edges of panel c of row r, positive inside.
fn panel_dist(r: f32, c: f32, n: f32, p: vec2f) -> f32 {
    return min(min(row_dist(r, p), -row_dist(r + 1.0, p)), min(col_dist(r, c, n, p), -col_dist(r, c + 1.0, n, p)));
}

// A point inside panel c of row r, as far from its top as from its bottom and from its left as from its right.
fn panel_center(r: f32, c: f32, n: f32) -> vec2f {
    let ra = ratio();
    // The sums of the distances to the opposite edges are linear: find where they are 0.
    let y0 = row_dist(r, vec2f(0.5 * ra, 0.0)) + row_dist(r + 1.0, vec2f(0.5 * ra, 0.0));
    let y1 = row_dist(r, vec2f(0.5 * ra, 1.0)) + row_dist(r + 1.0, vec2f(0.5 * ra, 1.0));
    let y = y0 / (y0 - y1);
    let x0 = col_dist(r, c, n, vec2f(0.0, y)) + col_dist(r, c + 1.0, n, vec2f(0.0, y));
    let x1 = col_dist(r, c, n, vec2f(1.0, y)) + col_dist(r, c + 1.0, n, vec2f(1.0, y));
    return vec2f(x0 / (x0 - x1), y);
}

fn panel_time(k: f32, total: f32) -> f32 {
    let t0 = START + (END - START - PUNCH) * k / max(total - 1.0, 1.0);
    return clamp((params.progress - t0) / PUNCH, 0.0, 1.0);
}

fn lift(t: f32) -> f32 {
    let u = 1.0 - (1.0 - t) * (1.0 - t);
    return sin(PI * u);
}

fn panel_image(p: vec2f, center: vec2f, t: f32) -> vec4f {
    let ra = ratio();
    let k = lift(t);
    let q = center + (p - center) / (1.0 + 0.1 * k);
    let uv = vec2f(q.x / ra, 1.0 - q.y);
    if (t <= 0.0) { return from_color(uv); }
    if (t >= 1.0) { return to_color(uv); }
    let v = p - center;
    let a = (atan2(v.y, v.x + 1e-6) + PI) / (2.0 * PI) * SPIKES + center.x * 7.0;
    let i = floor(a);
    // The spike index wraps around so that the star has no seam where the angle wraps.
    let spike = (1.0 - abs(2.0 * (a - i) - 1.0)) * (0.5 + 0.5 * hash(vec2f(i - SPIKES * floor(i / SPIKES), center.y * 13.0 + seed())));
    // Large enough to cover the widest panel, a whole row of a wide frame.
    let burst = 1.5 * max(1.0, ra / 1.8) * smoothstep(0.06, 0.42, t);
    let d = length(v) - burst * (0.62 + 0.38 * spike);
    let w = 1.4 * INK;
    let c = mix(to_color(uv), params.border_color, smoothstep(-w - EDGE, -w + EDGE, d));
    return mix(c, from_color(uv), smoothstep(-EDGE, EDGE, d));
}

// The panel drawn over color: its gutter edge at g from its edges, its ink border inside it.
fn draw_panel(color: vec4f, img: vec4f, d: f32, g: f32, ink: f32, fade: f32) -> vec4f {
    let c = mix(params.border_color, img, mix(1.0, smoothstep(g + ink - EDGE, g + ink + EDGE, d), fade));
    return mix(color, c, mix(1.0, smoothstep(g - EDGE, g + EDGE, d), fade));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = vec2f(uv.x * ratio(), 1.0 - uv.y);

    let open = smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    let g = 0.5 * params.gutter * open;
    let ink = INK * open;
    // The edges come in gently instead of popping in at half coverage.
    let fade = clamp(open * 6.0, 0.0, 1.0);

    let n0 = cols(0.0);
    let n1 = cols(1.0);
    let n2 = cols(2.0);
    let total = n0 + n1 + n2;

    let r = select(select(2.0, 1.0, row_dist(2.0, p) < 0.0), 0.0, row_dist(1.0, p) < 0.0);
    let n = select(select(n2, n1, r == 1.0), n0, r == 0.0);
    var c = select(select(2.0, 1.0, col_dist(r, 2.0, n, p) < 0.0 || n < 2.5), 0.0, col_dist(r, 1.0, n, p) < 0.0);
    c = min(c, n - 1.0);
    let first = select(select(n0 + n1, n0, r == 1.0), 0.0, r == 0.0);
    let t = panel_time(first + c, total);

    var color = params.gutter_color;
    if (t <= 0.0 || t >= 1.0) {
        color = draw_panel(color, panel_image(p, panel_center(r, c, n), t), panel_dist(r, c, n, p), g, ink, fade);
    }

    // The panels lifted off the page, the later ones on top: at most 4 of them punch at once.
    let spacing = (END - START - PUNCH) / max(total - 1.0, 1.0);
    // With a margin, so that a panel at the very end of its punch is not missed to rounding.
    let k_first = floor((progress - START - PUNCH) / spacing - 0.01) + 1.0;
    for (var i = 0; i < 4; i++) {
        let pk = k_first + f32(i);
        if (pk < 0.0 || pk > total - 0.5) { continue; }
        let pt = panel_time(pk, total);
        if (pt <= 0.0 || pt >= 1.0) { continue; }
        let pr = select(select(2.0, 1.0, pk < n0 + n1), 0.0, pk < n0);
        let pn = select(select(n2, n1, pr == 1.0), n0, pr == 0.0);
        let pc = pk - select(select(n0 + n1, n0, pr == 1.0), 0.0, pr == 0.0);
        let k = lift(pt);
        let center = panel_center(pr, pc, pn);
        let s = 1.0 + 0.08 * k;
        let sq = center + (p - vec2f(0.012, 0.018) * k - center) / s;
        let sd = panel_dist(pr, pc, pn, sq) - g;
        color = vec4f(color.rgb * (1.0 - 0.4 * k * fade * smoothstep(-0.02, 0.01, sd)), color.a);
        let q = center + (p - center) / s;
        color = draw_panel(color, panel_image(q, center, pt), panel_dist(pr, pc, pn, q), g, ink, 1.0);
    }
    return color;
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
