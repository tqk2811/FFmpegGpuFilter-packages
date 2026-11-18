// Port of BlockCover.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BlockCover.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const DURATION: f32 = 0.14; // of one block's pop, in progress
const CUT: f32 = 0.45; // the frame is fully covered from CUT - HOLD to CUT + HOLD
const HOLD: f32 = 0.02;

var<private> g_progress: f32;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Eases from 0 to 1, a little past 1 (more with a larger c) and back.
fn back_out(t: f32, c: f32) -> f32 {
    let u = t - 1.0;
    return 1.0 + (c + 1.0) * u * u * u + c * u * u;
}

// When a cell's block starts to pop in (.x) and to pop out (.y).
fn timing(cell: vec2f) -> vec2f {
    return vec2f(
        (CUT - HOLD - DURATION) * hash(cell + 0.5),
        CUT + HOLD + (1.0 - CUT - HOLD - DURATION) * hash(cell + 71.7));
}

fn block_scale(cell: vec2f, c: f32) -> f32 {
    let t = timing(cell);
    let a = clamp((g_progress - t.x) / DURATION, 0.0, 1.0);
    let b = clamp((g_progress - t.y) / DURATION, 0.0, 1.0);
    if (b > 0.0) { return (1.0 - b) * (1.0 - b); }
    return back_out(a, c);
}

fn coverage(q: vec2f, cell: vec2f, s: f32, sm: f32) -> f32 {
    // At scale 1, its solid part fills the whole cell, so that a covered frame shows no seams.
    let h = s * (0.5 + sm);
    let d = abs(q - cell - 0.5);
    if (s > 0.0) { return 1.0 - smoothstep(h - sm, h, max(d.x, d.y)); }
    return 0.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    let ratio = globals.size.x / globals.size.y;
    let color = params.color;
    let n_long = max(f32(params.blocks), 1.0);
    var n = vec2f(max(1.0, floor(n_long * ratio + 0.5)), n_long);
    if (ratio >= 1.0) { n = vec2f(n_long, max(1.0, floor(n_long / ratio + 0.5))); }
    let q = uv * n;
    let cell = floor(q);
    let sm = max(params.smoothness, 0.001);
    let c = 2.0 * clamp(params.pop, 0.0, 1.0);
    let s = block_scale(cell, c);
    if (s >= 1.0) { return color; }
    var cover = coverage(q, cell, s, sm);
    // A neighbour's block can overshoot onto this cell, near its border only.
    let u = -2.0 * c / (3.0 * (c + 1.0));
    let reach = back_out(1.0 + u, c) * (0.5 + sm);
    let o = abs(q - cell - 0.5);
    if (max(o.x, o.y) > 1.0 - reach) {
        for (var j = -1; j <= 1; j++) {
            for (var i = -1; i <= 1; i++) {
                let nb = cell + vec2f(f32(i), f32(j));
                let inside = step(vec2f(0.0), nb) * step(nb, n - 1.0);
                if (inside.x * inside.y > 0.0 && (i != 0 || j != 0)) {
                    cover = max(cover, coverage(q, nb, block_scale(nb, c), sm));
                }
            }
        }
    }
    let t = timing(cell);
    var under = to_color(uv);
    if (progress < 0.5 * (t.x + DURATION + t.y)) { under = from_color(uv); }
    return mix(under, color, cover);
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
