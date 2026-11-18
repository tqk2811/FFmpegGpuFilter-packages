// Port of GeometricCollage.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GeometricCollage.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// Shortest duration of the swing of one layer, delay of a cell's second piece, lead of a plate over its piece.
const DUR: f32 = 0.24;
const GAP: f32 = 0.07;
const LEAD: f32 = 0.06;
// Part of a swing after which a layer has turned into place, and only comes down flat onto the paper.
const SETTLE: f32 = 0.8;
const EDGE: f32 = 0.002;

var<private> g_progress: f32;

fn gl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

// The cell's layout seen from its first piece: the local point turned by k quarter turns around the cell center.
fn orient(l: vec2f, k: f32) -> vec2f {
    let c = l - 0.5;
    if (k < 0.5) { return l; }
    if (k < 1.5) { return vec2f(-c.y, c.x) + 0.5; }
    if (k < 2.5) { return 0.5 - c; }
    return vec2f(c.y, -c.x) + 0.5;
}

// The cell corner that orient(., k) maps to the corner (0, 0): the first piece's pivot.
fn pivot_corner(k: f32) -> vec2f {
    if (k < 0.5) { return vec2f(0.0, 0.0); }
    if (k < 1.5) { return vec2f(0.0, 1.0); }
    if (k < 2.5) { return vec2f(1.0, 1.0); }
    return vec2f(1.0, 0.0);
}

// Signed distance (in cell units) to the cell's first piece, negative inside; the second piece is its complement.
fn shape_dist(o: vec2f, kind: f32) -> f32 {
    if (kind < 0.5) { return length(o) - 1.0; }                  // quarter disc around the pivot
    if (kind < 1.5) { return length(o - vec2f(0.5, 0.0)) - 0.5; } // half disc on an edge
    return (o.x + o.y - 1.0) * 0.70710678;                         // triangle
}

fn piece_dist(l: vec2f, cell: vec2f, piece: f32) -> f32 {
    let k = floor(hash12(cell + 1.7) * 4.0);
    // Cells side by side never share a shape.
    let sd = shape_dist(orient(l, k), gl_mod(cell.x + 2.0 * cell.y + 1.0, 3.0));
    return select(sd, -sd, piece > 0.5);
}

fn box_dist(l: vec2f) -> f32 {
    return min(min(l.x, l.y), min(1.0 - l.x, 1.0 - l.y));
}

fn ease_out_cubic(t: f32) -> f32 {
    let u = 1.0 - clamp(t, 0.0, 1.0);
    return 1.0 - u * u * u;
}

fn lift(t: f32) -> f32 {
    return 1.0 - smoothstep(0.3, 1.0, t);
}

// The time over which the cells start one after another, and the duration of a swing, which gets
// longer when the cells start closer together, so that the last piece always lands just before the end.
fn spread() -> f32 {
    return (1.0 - DUR - GAP - LEAD - 0.02) * clamp(params.stagger, 0.0, 1.0);
}
fn swing() -> f32 {
    return 1.0 - GAP - LEAD - 0.02 - spread();
}

// When the first piece of a cell starts to swing in; the second one starts GAP later, and a plate LEAD before its piece.
fn start_time(cell: vec2f, n: vec2f) -> f32 {
    var order = (cell.x + (n.y - 1.0 - cell.y)) / max(n.x + n.y - 2.0, 1.0);
    order = clamp(order * 0.75 + 0.25 * hash12(cell + 4.4), 0.0, 1.0);
    return LEAD + spread() * order;
}

// The local point in the cell of a swinging layer at its local time t (0 < t < 1), seen at the
// frame point p, and its scale.
fn swing_point(p: vec2f, cell: vec2f, cs: vec2f, piece: f32, t: f32) -> vec3f {
    let pc = pivot_corner(floor(hash12(cell + 1.7) * 4.0));
    let piv = (cell + select(1.0 - pc, pc, piece < 0.5)) * cs;
    let sgn = select(1.0, -1.0, hash12(cell + vec2f(piece * 3.3, 5.2)) < 0.5);
    let s = smoothstep(0.0, 0.45, t) * (1.0 + 0.1 * lift(t));
    let a = sgn * 0.5 * PI * (1.0 - ease_out_cubic(t / SETTLE));
    let ca = cos(a);
    let sa = sin(a);
    var d = p - piv;
    d = vec2f(ca * d.x + sa * d.y, -sa * d.x + ca * d.y) / max(s, 0.001);
    return vec3f((piv + d) / cs - cell, s);
}

fn layer_cover(p: vec2f, cell: vec2f, cs: vec2f, piece: f32, t: f32) -> vec3f {
    let q = swing_point(p, cell, cs, piece, t);
    if (q.z < 0.01) { return vec3f(0.0); }
    let e = EDGE / (min(cs.x, cs.y) * q.z);
    let m = clamp(box_dist(q.xy) / e + 0.5, 0.0, 1.0) * clamp(-piece_dist(q.xy, cell, piece) / e + 0.5, 0.0, 1.0);
    return vec3f(m, clamp(q.xy, vec2f(0.0), vec2f(1.0)));
}

fn layer_shadow(p: vec2f, cell: vec2f, cs: vec2f, piece: f32, t: f32) -> f32 {
    let h = lift(t);
    let q = swing_point(p - vec2f(0.07, -0.1) * h * cs.y, cell, cs, piece, t);
    if (q.z < 0.01) { return 0.0; }
    let soft = 0.02 + 0.05 * h;
    return h * (1.0 - smoothstep(-soft, soft, piece_dist(q.xy, cell, piece))) * smoothstep(-soft, soft, box_dist(q.xy));
}

fn plate_color(cell: vec2f, piece: f32) -> vec4f {
    let c = gl_mod(floor(hash12(cell * 1.3 + 0.7) * 3.0) + piece, 3.0);
    if (c < 0.5) { return params.color1; }
    if (c < 1.5) { return params.color2; }
    return params.color3;
}

fn premultiplied(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    let ratio = globals.size.x / globals.size.y;
    let plates = params.plates != 0u;
    let kc = f32(max(params.cells, 1));
    var n = vec2f(kc, max(1.0, floor(kc / ratio + 0.5)));
    if (ratio >= 1.0) { n = vec2f(max(1.0, floor(ratio * kc + 0.5)), kc); }
    let cs = vec2f(ratio, 1.0) / n;
    let p = uv * vec2f(ratio, 1.0);
    let cell0 = floor(p / cs);
    let sw = swing();

    // The paper: the first clip, where the pieces that have landed show the second one. They lie
    // flat side by side and tile the frame exactly, with hard cell edges and antialiased edges
    // between the two pieces of a cell.
    let l0 = p / cs - cell0;
    let t00 = start_time(cell0, n);
    let sd0 = piece_dist(l0, cell0, 0.0);
    let e0 = EDGE / min(cs.x, cs.y);
    var landed = select(0.0, clamp(-sd0 / e0 + 0.5, 0.0, 1.0), progress >= t00 + sw)
        + select(0.0, clamp(sd0 / e0 + 0.5, 0.0, 1.0), progress >= t00 + GAP + sw);
    // The layers still in the air, and the plates not yet covered by their pieces: the top one at p
    // and the one under it by start time, as (start, coverage, plate, piece) and (cell, local point).
    var top = vec4f(-1.0, 0.0, 0.0, 0.0);
    var top_pos = vec4f(0.0);
    var und = vec4f(-1.0, 0.0, 0.0, 0.0);
    var und_pos = vec4f(0.0);
    for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
            let cell = cell0 + vec2f(f32(dx), f32(dy));
            if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= n.x || cell.y >= n.y) { continue; }
            let tc = start_time(cell, n);
            for (var pc = 0; pc < 2; pc++) {
                let piece = f32(pc);
                let t0 = tc + GAP * piece;
                let tp = (progress - t0) / sw;
                for (var ly = 0; ly < 2; ly++) {
                    let is_plate = select(0.0, 1.0, ly == 0);
                    if (is_plate > 0.5 && !plates) { continue; }
                    let ts = t0 - LEAD * is_plate;
                    let t = (progress - ts) / sw;
                    // A landed piece is part of the paper, and its plate fades out under it once it has turned into place.
                    if (t <= 0.0 || tp >= 1.0 || (is_plate > 0.5 && tp >= SETTLE)) { continue; }
                    var lc = layer_cover(p, cell, cs, piece, min(t, 1.0));
                    if (is_plate > 0.5) { lc.x *= 1.0 - smoothstep(SETTLE - 0.1, SETTLE, tp); }
                    if (lc.x <= 0.0) { continue; }
                    let cur = vec4f(ts, lc.x, is_plate, piece);
                    let cur_pos = vec4f(cell, lc.yz);
                    if (ts > top.x) {
                        und = top;
                        und_pos = top_pos;
                        top = cur;
                        top_pos = cur_pos;
                    } else if (ts > und.x) {
                        und = cur;
                        und_pos = cur_pos;
                    }
                }
            }
        }
    }
    // A piece coming down next to its landed complement does not overlap it along their common edge: their coverages add up.
    if (top.z < 0.5 && und.x < 0.0 && top_pos.x == cell0.x && top_pos.y == cell0.y) {
        landed = select(1.0, landed / (1.0 - top.y), top.y < 1.0);
    }
    var c = mix(premultiplied(from_color(uv)), premultiplied(to_color(uv)), clamp(landed, 0.0, 1.0));
    if (und.x >= 0.0) {
        var uc = to_color((und_pos.xy + und_pos.zw) * cs / vec2f(ratio, 1.0));
        if (und.z > 0.5) { uc = plate_color(und_pos.xy, und.w); }
        c = mix(c, premultiplied(uc), und.y);
    }
    if (top.x >= 0.0) {
        var tc = to_color((top_pos.xy + top_pos.zw) * cs / vec2f(ratio, 1.0));
        if (top.z > 0.5) { tc = plate_color(top_pos.xy, top.w); }
        c = mix(c, premultiplied(tc), top.y);
    }

    var sh = 0.0;
    if (params.shadow > 0.0) {
        for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
                let cell = cell0 + vec2f(f32(dx), f32(dy));
                if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= n.x || cell.y >= n.y) { continue; }
                let tc = start_time(cell, n);
                for (var pc = 0; pc < 2; pc++) {
                    let piece = f32(pc);
                    let t0 = tc + GAP * piece;
                    let tp = (progress - t0) / sw;
                    for (var ly = 0; ly < 2; ly++) {
                        let is_plate = select(0.0, 1.0, ly == 0);
                        if (is_plate > 0.5 && (!plates || tp >= SETTLE)) { continue; }
                        let ts = t0 - LEAD * is_plate;
                        let t = (progress - ts) / sw;
                        if (ts <= top.x || t <= 0.0 || t >= 1.0) { continue; }
                        sh = max(sh, layer_shadow(p, cell, cs, piece, t));
                    }
                }
            }
        }
    }
    c = vec4f(c.rgb * (1.0 - 0.7 * clamp(params.shadow, 0.0, 1.0) * sh), c.a);
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
    return vec4f(0.0);
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
