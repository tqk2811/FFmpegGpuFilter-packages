// Port of TileConveyor.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TileConveyor.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const EDGE: f32 = 0.0016;

fn fmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

// Hilbert curve from the bottom left cell to the bottom right one; -1 and n * n are the cells just outside.
fn cell_at(d: f32, n: f32) -> vec2f {
    if (d < 0.0) { return vec2f(-1.0, 0.0); }
    if (d > n * n - 0.5) { return vec2f(n, 0.0); }
    var p = vec2f(0.0);
    var t = d;
    var s = 1.0;
    for (var i = 0; i < 3; i++) {
        if (s < n) {
            let rx = fmod(floor(t / 2.0), 2.0);
            let ry = abs(fmod(t, 2.0) - rx);
            if (ry < 0.5) {
                if (rx > 0.5) { p = s - 1.0 - p; }
                p = p.yx;
            }
            p += s * vec2f(rx, ry);
            t = floor(t / 4.0);
            s *= 2.0;
        }
    }
    return p;
}

fn index_at(c: vec2f, n: f32) -> f32 {
    var d = 0.0;
    var p = c;
    var s = n / 2.0;
    for (var i = 0; i < 3; i++) {
        if (s >= 1.0) {
            let rx = fmod(floor(p.x / s), 2.0);
            let ry = fmod(floor(p.y / s), 2.0);
            d += s * s * select(ry, 3.0 - ry, rx > 0.5);
            if (ry < 0.5) {
                if (rx > 0.5) { p = n - 1.0 - p; }
                p = p.yx;
            }
            s /= 2.0;
        }
    }
    return d;
}

fn turns(a0: vec2f, c: vec2f, b0: vec2f) -> f32 {
    let a = a0 - c;
    let b = b0 - c;
    return abs(a.x * b.y - a.y * b.x);
}

fn sd_box(p: vec2f, b: vec2f, r: f32) -> f32 {
    let q = abs(p) - b + r;
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

fn sd_segment(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let pa = p - a;
    let ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

fn mirror_abs(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - abs(v)); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = floor(exp2(clamp(f32(params.order), 1.0, 3.0)) + 0.5);
    let nn = n * n;
    let asp = vec2f(ratio, 1.0);
    let open = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
    let q = clamp((progress - 0.07) / 0.86, 0.0, 1.0);
    let dd = nn * mix(q, q * q * (3.0 - 2.0 * q), 0.7);
    let kk = floor(dd);
    var f = dd - kk;
    // Slower at the cells so that the grid reads, never stopping.
    f -= 0.5 * sin(6.2831853 * f) / 6.2831853;

    let g = uv * n;
    let cell = clamp(floor(g), vec2f(0.0), vec2f(n - 1.0));
    let dc = index_at(cell, n);
    let px = EDGE * n;
    let hs = 0.5 - 0.5 * clamp(params.gap, 0.05, 0.4) * open;
    let radius = 0.1 * open;

    let gs = g * asp;
    let tw = 0.1 * min(ratio, 1.0);
    let cc = (cell + 0.5) * asp;
    let dl = min(sd_segment(gs, cc, (cell_at(dc - 1.0, n) + 0.5) * asp),
                 sd_segment(gs, cc, (cell_at(dc + 1.0, n) + 0.5) * asp));
    var col = mix(params.tray, params.track, (1.0 - smoothstep(tw - px, tw + px, dl)) * (0.65 + 0.35 * smoothstep(0.0, 0.35 * tw, dl)));

    var shadow = 0.0;
    var acc = vec4f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < 9; i++) {
        let nc = cell + vec2f(f32(i % 3), f32(i / 3)) - 1.0;
        let entry = nc.x == -1.0 && nc.y == 0.0;
        if (!entry && (min(nc.x, nc.y) < 0.0 || max(nc.x, nc.y) > n - 1.0)) { continue; }
        // One tile per path segment: the one between cell k and cell k + 1.
        let k = select(index_at(nc, n), -1.0, entry);
        let j = k - kk;
        if (j < -nn) { continue; }
        let c1 = cell_at(k + 1.0, n);
        let lc = g - 0.5 - mix(nc, c1, f);
        let lp = lc * asp;
        // Two tiles on either side of a turn are only max(f, 1 - f) apart on each axis: shrink them to pass.
        let lim = mix(0.5, 0.25 + 0.5 * (sqrt((f - 0.5) * (f - 0.5) + 0.0025) - 0.05), open);
        let h = select(hs, min(hs, lim), max(turns(cell_at(k - 1.0, n), nc, c1), turns(nc, c1, cell_at(k + 2.0, n))) > 0.5);
        // At rest the tiles in the grid overlap by a few pixels so that no seam shows, the entry tile stays outside.
        let hb = h * asp + 3.0 * px * (1.0 - open) * select(-1.0, 1.0, k >= 0.0 && k < nn);
        let sd = sd_box(lp, hb, radius * h);
        // Fading before half a cell keeps the shadow inside the cells that search for this tile.
        let fade = 1.0 - smoothstep(0.4, 0.5, max(abs(lc.x), abs(lc.y)));
        shadow = max(shadow, open * fade * (1.0 - smoothstep(-0.04, 0.12, sd_box(lp - vec2f(0.04, -0.06), hb, radius * h))));
        let cover = 1.0 - smoothstep(-px, px, sd);
        if (cover <= 0.0) { continue; }
        let src = cell_at(select(j + nn, j, j >= 0.0), n);
        let suv = mirror_abs((src + 0.5 + 0.5 * lp / (h * asp)) / n);
        var c = select(to_color(suv), from_color(suv), j >= 0.0);
        let rim = 1.0 - smoothstep(0.0, 0.05, -sd);
        let lit = dot(normalize(lp / hb + 1e-5), vec2f(-0.7071, 0.7071));
        c = vec4f(c.rgb * (1.0 + params.shading * open * (rim * 0.35 * lit - 0.08 * (1.0 - rim))), c.a);
        acc = mix(acc, c, cover);
        alpha = mix(alpha, 1.0, cover);
    }
    col = vec4f(col.rgb * (1.0 - 0.6 * params.shading * shadow), col.a);
    return mix(col, acc / max(alpha, 1e-4), alpha);
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
