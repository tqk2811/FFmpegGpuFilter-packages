// Port of TileShuffle.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TileShuffle.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const MAX_TILES: f32 = 8.0;
// Rounds of swaps, along the rows in even rounds and along the columns in odd ones.
const ROUNDS: i32 = 4;
// The gaps open over [0, OPEN] and close over [1 - OPEN, 1].
const OPEN: f32 = 0.15;
// The swaps run over [START, 1 - START].
const START: f32 = 0.07;
// Each round sweeps across the frame from its top left corner, a swap starting WAVE later than the
// one a cell before it, plus up to JITTER, in swap durations. The next round follows
// 1 + WAVE + JITTER behind, so no tile starts a swap before it has finished the one before.
const WAVE: f32 = 0.4;
const JITTER: f32 = 0.15;
// Growth of the lifted tile of a swap and shrink of the other one, as seen in perspective.
const GROW: f32 = 0.08;
const SINK: f32 = 0.03;
// How far the tile that slides over swings out of its line, in cells.
const SWING: f32 = 0.2;
const EDGE: f32 = 0.0015;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn modf_(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn box_dist(p: vec2f, b: vec2f, r: f32) -> f32 {
    let d = abs(p) - b + r;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// The cell that cell c swaps with in round k (c itself when it has no partner). Each line of the
// round pairs its cells two by two, from its first or from its second cell; a line of two cells
// swaps them in one of its two rounds only, so that the second swap does not undo the first.
fn partner(c: vec2f, k: f32, n: vec2f) -> vec2f {
    let rows = modf_(k, 2.0) < 0.5;
    let a = select(c.y, c.x, rows);
    let len = select(n.y, n.x, rows);
    let line = select(c.x, c.y, rows);
    var par: f32;
    if (len < 2.5) { par = modf_(line + floor(0.5 * k), 2.0); } else { par = step(0.5, hash12(vec2f(line, 7.0 * k + 1.0))); }
    var b = select(a - 1.0, a + 1.0, modf_(a - par, 2.0) < 0.5);
    if (a < par || b >= len) { b = a; }
    return select(vec2f(c.x, b), vec2f(b, c.y), rows);
}

fn differ(a: vec2f, b: vec2f) -> bool {
    return abs(a.x - b.x) + abs(a.y - b.y) > 0.5;
}

// Time of the swap of cells c and b in round k, from 0 when it starts to 1 when it ends;
// sw is the duration of a swap and the time between two rounds.
fn swap_time(c: vec2f, b: vec2f, k: f32, n: vec2f, sw: vec2f, progress: f32) -> f32 {
    let m = 0.5 * (c + b);
    let t0 = START + k * sw.y + sw.x * (WAVE * (m.x + n.y - 1.0 - m.y) + JITTER * hash12(min(c, b) + 13.0 * k));
    return (progress - t0) / sw.x;
}

// The swap of the tile that cell c holds now, the first swap of the cell that is not over yet:
// x its round (ROUNDS once the cell has no swap left), y its time, zw the partner cell.
fn current_swap(c: vec2f, n: vec2f, sw: vec2f, progress: f32) -> vec4f {
    var cur = vec4f(f32(ROUNDS), 0.0, c);
    var found = false;
    for (var i = 0; i < ROUNDS; i++) {
        let k = f32(i);
        if (!found) {
            let b = partner(c, k, n);
            if (differ(b, c)) {
                let u = swap_time(c, b, k, n, sw, progress);
                if (u < 1.0) {
                    cur = vec4f(k, max(u, 0.0), b);
                    found = true;
                }
            }
        }
    }
    return cur;
}

// Lift of the tile of cell c during its current swap: positive for the tile that slides over,
// negative for the one that slides under.
fn swap_lift(c: vec2f, cur: vec4f) -> f32 {
    if (cur.x >= f32(ROUNDS)) { return 0.0; }
    let u = cur.y;
    let bell = 16.0 * u * u * (1.0 - u) * (1.0 - u);
    let over = (hash12(min(c, cur.zw) + 13.0 * cur.x + 3.7) < 0.5) == (c.x + c.y < cur.z + cur.w);
    return select(-bell, bell, over);
}

// Center of that tile, in cells: the tile that slides over swings out a little to pass the other.
fn swap_pos(c: vec2f, cur: vec4f, lift: f32) -> vec2f {
    let u = cur.y;
    let e = u * u * u * (u * (6.0 * u - 15.0) + 10.0);
    let side = (cur.zw - c).yx * select(-1.0, 1.0, hash12(cur.zw + c + 1.9 * cur.x) < 0.5);
    return mix(c, cur.zw, e) + 0.5 + SWING * max(lift, 0.0) * side;
}

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - abs(v));
}

// The color of a tile: its picture points src (first clip xy, second zw) turned by w, brightened as
// it lifts, with a pale rim along its edge (at distance e) and darkened by the shadows sh above it.
fn tile_color(src: vec4f, w: f32, lift: f32, e: f32, sh: f32) -> vec4f {
    var c: vec4f;
    if (w <= 0.0) { c = from_color(mirror(src.xy)); }
    else if (w >= 1.0) { c = to_color(mirror(src.zw)); }
    else { c = mix(from_color(mirror(src.xy)), to_color(mirror(src.zw)), w); }
    let up = max(lift, 0.0);
    let rim = 0.2 * up * (1.0 - smoothstep(0.0, 0.006, e));
    let rgb = mix(clamp(c.rgb * (1.0 + 0.06 * up + 0.1 * min(lift, 0.0)) * (1.0 - sh), vec3f(0.0), vec3f(1.0)), vec3f(1.0), rim);
    return vec4f(rgb, c.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // At least two tiles along each side, so that the tiles move along both.
    let nl = clamp(f32(params.tiles), 2.0, MAX_TILES);
    var n: vec2f;
    if (ratio >= 1.0) { n = vec2f(nl, clamp(floor(nl / ratio + 0.5), 2.0, MAX_TILES)); }
    else { n = vec2f(clamp(floor(nl * ratio + 0.5), 2.0, MAX_TILES), nl); }
    let cell = vec2f(ratio, 1.0) / n;
    let x = uv * vec2f(ratio, 1.0);
    let here = clamp(floor(uv * n), vec2f(0.0), n - 1.0);
    let open = smoothstep(0.0, OPEN, progress) * (1.0 - smoothstep(1.0 - OPEN, 1.0, progress));
    let g = clamp(params.gap, 0.0, 0.15) * open * min(cell.x, cell.y);
    // Without gaps, the tiles overlap a little to hide their seams.
    let hb = vec2f(0.5 * cell - 0.5 * g + EDGE * max(1.0 - 0.5 * g / EDGE, 0.0));
    let rad = 0.6 * g;
    // Duration of a swap, and time between two rounds: the last swap ends at 1 - START.
    let gap_k = 1.0 + WAVE + JITTER;
    let sd = (1.0 - 2.0 * START) / (f32(ROUNDS - 1) * gap_k + 1.0 + WAVE * (n.x + n.y - 2.0) + JITTER);
    let sw = vec2f(sd, sd * gap_k);

    // The two highest tiles seen here: height, coverage, lift, turn, edge distance, picture points.
    var z1 = -9.0; var z2 = -9.0;
    var m1 = 0.0; var m2 = 0.0;
    var l1 = 0.0; var l2 = 0.0;
    var w1 = 0.0; var w2 = 0.0;
    var e1 = 0.0; var e2 = 0.0;
    var s1 = vec4f(0.0); var s2 = vec4f(0.0);
    for (var j = 0; j < 5; j++) {
        for (var i = 0; i < 5; i++) {
            let o = vec2f(f32(i) - 2.0, f32(j) - 2.0);
            let c = here + o;
            if (abs(o.x) + abs(o.y) > 3.5 || c.x < 0.0 || c.y < 0.0 || c.x >= n.x || c.y >= n.y) { continue; }
            let cur = current_swap(c, n, sw, progress);
            let lift = swap_lift(c, cur);
            let sc = 1.0 + GROW * max(lift, 0.0) - SINK * max(-lift, 0.0);
            let q = (x - swap_pos(c, cur, lift) * cell) / sc;
            let e = -box_dist(q, hb, rad) * sc;
            let cov = clamp(e / EDGE + 0.5, 0.0, 1.0);
            // Where resting tiles overlap at their edges, the one that covers this point fully comes first.
            let z = lift + 0.001 * cov;
            if (cov <= 0.0 || z <= z2) { continue; }
            // The cell the tile started from, the one it ends in, and its swaps before and from the current one.
            var s = c;
            var h = c;
            var before = 0.0;
            var after = 0.0;
            for (var k = ROUNDS - 1; k >= 0; k--) {
                if (f32(k) < cur.x) {
                    let b = partner(s, f32(k), n);
                    if (differ(b, s)) { before += 1.0; }
                    s = b;
                }
            }
            for (var k = 0; k < ROUNDS; k++) {
                if (f32(k) >= cur.x) {
                    let b = partner(h, f32(k), n);
                    if (differ(b, h)) { after += 1.0; }
                    h = b;
                }
            }
            // Each tile turns to the second clip during one of its swaps, so the second clip comes
            // scrambled and the last rounds sort it out; a tile that never moves turns in place at the end.
            let turn = floor(hash12(h + 21.3) * (before + after));
            var w: f32;
            if (before + after < 0.5) { w = smoothstep(1.0 - 2.0 * OPEN, 1.0 - START, progress); }
            else if (before > turn) { w = 1.0; }
            else if (before == turn) { w = smoothstep(0.35, 0.65, cur.y); }
            else { w = 0.0; }
            let l = q / cell + 0.5;
            let src = vec4f((s + l) / n, (h + l) / n);
            if (z > z1) {
                z2 = z1; m2 = m1; l2 = l1; w2 = w1; e2 = e1; s2 = s1;
                z1 = z; m1 = cov; l1 = lift; w1 = w; e1 = e; s1 = src;
            } else {
                z2 = z; m2 = cov; l2 = lift; w2 = w; e2 = e; s2 = src;
            }
        }
    }

    var sh0 = 0.0;
    var sh1 = 0.0;
    var sh2 = 0.0;
    let light = vec2f(0.45, -0.75) * min(cell.x, cell.y);
    for (var j = 0; j < 5; j++) {
        for (var i = 0; i < 5; i++) {
            let o = vec2f(f32(i) - 2.0, f32(j) - 2.0);
            let c = here + o;
            if (abs(o.x) + abs(o.y) > 3.5 || c.x < 0.0 || c.y < 0.0 || c.x >= n.x || c.y >= n.y) { continue; }
            let cur = current_swap(c, n, sw, progress);
            let lift = swap_lift(c, cur);
            let up = max(lift, 0.0);
            let d = x - swap_pos(c, cur, lift) * cell - light * (0.15 * g / min(cell.x, cell.y) + 0.06 * up);
            let blur = 0.003 + 0.25 * g + 0.04 * up * min(cell.x, cell.y);
            let sdist = box_dist(d, hb * (1.0 + GROW * up - SINK * max(-lift, 0.0)), rad);
            let a = (1.0 - smoothstep(-blur, blur, sdist)) * (0.75 - 0.25 * up);
            sh0 = max(sh0, a);
            if (lift > z2 + 0.01) { sh2 = max(sh2, a); }
            if (lift > z1 + 0.01) { sh1 = max(sh1, a); }
        }
    }

    let k = clamp(params.shadow, 0.0, 1.0);
    let tray = params.tray;
    var col = vec4f(tray.rgb * (1.0 - k * sh0), tray.a);
    // The lower tile only shows where the top one does not cover this point fully.
    if (m2 > 0.0 && m1 < 1.0) { col = mix(col, tile_color(s2, w2, l2, e2, k * sh2), m2); }
    if (m1 > 0.0) { col = mix(col, tile_color(s1, w1, l1, e1, k * sh1), m1); }
    return col;
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
