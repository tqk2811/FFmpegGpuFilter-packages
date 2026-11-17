// Port of SplitFlap.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SplitFlap.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.001;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn cell_time(cell: vec2f, grid: vec2f, progress: f32) -> f32 {
    let wave = (cell.x + 0.5 * (grid.y - 1.0 - cell.y)) / max(grid.x - 1.0 + 0.5 * (grid.y - 1.0), 1.0);
    let order = mix(wave, hash12(cell + 17.0), params.randomness);
    let delay = clamp(params.stagger, 0.0, 0.99);
    return clamp((progress - order * delay) / (1.0 - delay), 0.0, 1.0);
}

// The card on the front of the falling flap, at the cell's flip t.
fn flap_index(t: f32, n: f32) -> f32 { return min(floor(t * n), n - 1.0); }

// The falling flap's angle, 0 upright to PI down: it starts gently and lands fast.
fn flap_angle(t: f32, n: f32) -> f32 {
    let u = t * n - flap_index(t, n);
    return PI * u * (0.3 + 0.7 * u);
}

// Card i of a cell at the point lc of the card: the first clip first, the second last,
// and in between the second clip of another cell.
fn card(i: f32, n: f32, cell: vec2f, grid: vec2f, lc: vec2f) -> vec4f {
    if (i < 0.5) { return from_color((cell + lc) / grid); }
    var src = cell;
    if (i < n - 0.5) {
        src = floor(vec2f(hash12(cell * 3.7 + i * 11.3), hash12(cell * 5.3 + i * 7.9 + 1.7)) * grid);
    }
    return to_color((src + lc) / grid);
}

// 1 inside a half card, 0 in the gaps: x across the card and f the distance from the hinge, in cell sizes.
fn card_mask(x: f32, f: f32, cell_size: vec2f, g: f32) -> f32 {
    if (g <= 0.0) { return 1.0; }
    let e = EDGE * min(1.0, g / max(params.gap, 1e-4));
    // The gap at the hinge is half as wide as the one between the cells.
    let d = min(min(x, 1.0 - x) * cell_size.x, min(2.0 * f, 0.5 - f) * cell_size.y);
    return smoothstep(0.5 * g - e, 0.5 * g + e, d);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let grid = max(vec2f(f32(params.columns), f32(params.rows)), vec2f(1.0));
    let n = max(f32(params.flaps), 1.0);
    let cell_size = vec2f(ratio, 1.0) / grid / min(ratio, 1.0);
    let cell = floor(uv * grid);
    let l = uv * grid - cell;
    let g = params.gap * smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
    // w: height above the hinge, in cell heights.
    let w = l.y - 0.5;
    let upper = w >= 0.0;
    // The board behind the falling flaps.
    let t = cell_time(cell, grid, progress);
    let k = flap_index(t, n);
    let a = flap_angle(t, n);
    let started = t * n > k;
    let landed = t >= 1.0;
    let next = select(select(0.0, 1.0, landed), select(0.0, 1.0, started), upper);
    var color = card(k + next, n, cell, grid, l);
    if (started && !landed) {
        color = vec4f(color.rgb * (1.0 - 0.45 * shading * max(select(-cos(a), cos(a), upper), 0.0)), color.a);
    }
    color = mix(params.background, color, card_mask(l.x, abs(w), cell_size, g));
    // The falling flaps of this cell and of its neighbors, which grow beyond their cells as they come closer.
    var nearest = -1.0;
    for (var d = -1; d <= 1; d++) {
        let nc = cell + vec2f(f32(d), 0.0);
        if (nc.x < 0.0 || nc.x > grid.x - 1.0) { continue; }
        var nt = t;
        var na = a;
        if (d != 0) {
            nt = cell_time(nc, grid, progress);
            na = flap_angle(nt, n);
        }
        let fc = cos(na);
        let fs = sin(na);
        // A point at distance f from the hinge is at height f * fc and depth f * fs; nearer points look wider.
        if (abs(fc) < 1e-5 || (w >= 0.0) != (fc > 0.0)) { continue; }
        let f = w / fc;
        if (f > 0.5) { continue; }
        let z = f * fs;
        if (z <= nearest) { continue; }
        let lx = 0.5 + (l.x - f32(d) - 0.5) * (1.0 - params.perspective * z);
        if (lx < 0.0 || lx > 1.0) { continue; }
        let front = fc > 0.0;
        let lc = vec2f(lx, select(0.5 - f, 0.5 + f, front));
        let m = card_mask(lx, f, cell_size, g);
        if (m <= 0.0) { continue; }
        var img = card(flap_index(nt, n) + select(1.0, 0.0, front), n, nc, grid, lc);
        let lambert = select(0.4 * fs - 0.92 * fc, 0.92 * fc - 0.4 * fs, front) / 0.92;
        img = vec4f(img.rgb * mix(1.0 - shading, 1.0, clamp(lambert, 0.0, 1.0)), img.a);
        color = mix(color, img, m);
        nearest = z;
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
