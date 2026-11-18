// Port of HingedSquares.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HingedSquares.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0012;

// Turns v clockwise by the angle whose cosine and sine are cs.
fn rot(v: vec2f, cs: vec2f) -> vec2f {
    return vec2f(cs.x * v.x + cs.y * v.y, -cs.y * v.x + cs.x * v.y);
}

fn node(i: i32) -> vec2f { return vec2f(f32(i % 2), f32(i / 2)); }

fn parity(n: vec2f) -> f32 {
    let s = n.x + n.y;
    return select(-1.0, 1.0, s - 2.0 * floor(s / 2.0) < 0.5);
}

// The square nearest to w among the 4 around the cell g of a hinged lattice of unit squares:
// its local coordinates, the signed distance to it and its node index.
fn nearest(w: vec2f, g: vec2f, spacing: f32, off: vec2f, cs: vec2f) -> vec4f {
    var best = vec4f(0.0, 0.0, 1e5, 0.0);
    for (var i = 0; i < 4; i++) {
        let n = g + node(i);
        let l = rot(w - (n + off) * spacing, vec2f(cs.x, parity(n) * cs.y));
        let q = abs(l) - 0.5;
        let d = length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0);
        if (d < best.z) { best = vec4f(l, d, f32(i)); }
    }
    return best;
}

// The gap of that lattice around w: a rhombus centered at a node of the other lattice.
// Returns the local coordinates of the piece of the other clip it shows, and its node index.
fn gap(w: vec2f, g: vec2f, spacing: f32, off: vec2f, cs: vec2f) -> vec3f {
    var best = vec3f(0.0);
    var r = 1e5;
    for (var i = 0; i < 4; i++) {
        let n = g + node(i);
        let v = w - (n + off) * spacing;
        let h = select(cs, cs.yx, parity(n) > 0.0);
        let ri = abs(v.x) * h.y + abs(v.y) * h.x;
        if (ri < r) {
            r = ri;
            best = vec3f(rot(v, vec2f(0.7071068, parity(n) * 0.7071068)), f32(i));
        }
    }
    return best;
}

// Lattice coordinates (in squares, centered) to a mirrored texture uv that stays in the frame.
fn to_uv(c: vec2f, n: f32, ratio: f32) -> vec2f {
    let uv = c / (n * vec2f(ratio, 1.0)) + 0.5 + 1.0;
    return abs(uv - 2.0 * floor(uv / 2.0) - 1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = max(f32(params.cells), 1.0);
    let e = progress * progress * (3.0 - 2.0 * progress);
    let a = 0.5 * PI * e;
    // Turn of the squares in front: 0 to 45 degrees for the first clip, then 45 to 0 for the second.
    let th = min(a, 0.5 * PI - a);
    let cs = vec2f(cos(th), sin(th));
    let spacing = cs.x + cs.y;
    let scale = n * mix(1.0, spacing, clamp(params.zoom, 0.0, 1.0));
    let w = (uv - 0.5) * vec2f(ratio, 1.0) * scale;
    let first = a < 0.25 * PI;
    let off_f = select(vec2f(0.5), vec2f(0.0), first);
    let off_b = vec2f(0.5) - off_f;
    let g_f = floor(w / spacing - off_f);
    let g_b = floor(w / spacing - off_b);
    let f = nearest(w, g_f, spacing, off_f, cs);
    let b = gap(w, g_b, spacing, off_b, cs);
    let nf = g_f + node(i32(f.w));
    let nb = g_b + node(i32(b.z));
    let uv_f = to_uv(nf + off_f + f.xy, n, ratio);
    let uv_b = to_uv(nb + off_b + b.xy, n, ratio);
    var col_f = select(to_color(uv_f), from_color(uv_f), first);
    var col_b = select(from_color(uv_b), to_color(uv_b), first);
    let depth = clamp(params.shading, 0.0, 1.0) * sin(4.0 * th);
    if (depth > 0.0) {
        let ws = w - vec2f(0.12, -0.12) * depth;
        let sh = nearest(ws, floor(ws / spacing - off_f), spacing, off_f, cs);
        col_b = vec4f(col_b.rgb * (1.0 - 0.75 * depth * (1.0 - smoothstep(-0.12, 0.25, sh.z))), col_b.a);
    }
    let side = select(vec2f(0.0, sign(f.y)), vec2f(sign(f.x), 0.0), abs(f.x) > abs(f.y));
    let facing = dot(rot(side, vec2f(cs.x, -parity(nf) * cs.y)), vec2f(-0.7071, 0.7071));
    let rim = smoothstep(-0.07, -0.01, f.z);
    col_f = vec4f(col_f.rgb * (1.0 + 0.35 * depth * rim * facing), col_f.a);
    // Anti-aliased edges; the squares overlap a little to hide the gaps until they are a few pixels wide.
    let aa = EDGE * scale;
    let seal = aa * (1.0 - smoothstep(0.0, 3.0 * aa, cs.y));
    let cover = 1.0 - smoothstep(-aa, aa, f.z - seal);
    return mix(col_b, col_f, cover);
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
