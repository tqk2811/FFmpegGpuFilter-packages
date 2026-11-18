// Port of QuadtreeBlocks.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/QuadtreeBlocks.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Number of levels: the smallest blocks are 1/64 of the largest ones.
const LEVELS: i32 = 7;
const AA: f32 = 0.0015;
const SEAM: f32 = 0.0025;

fn img(p: vec2f, incoming: bool, ratio: f32) -> vec4f {
    let uv = vec2f(p.x / ratio, p.y);
    if (incoming) { return to_color(uv); }
    return from_color(uv);
}

// 1 on a seam between the blocks of size s, 0 elsewhere; the frame's border has none.
fn seam_line(p: vec2f, s: vec2f, ratio: f32) -> f32 {
    let frame = vec2f(ratio, 1.0);
    let lo = floor(p / s) * s;
    let hi = lo + s;
    var q = vec2f(1.0);
    if (lo.x > AA) { q.x = p.x - lo.x; }
    if (hi.x < frame.x - AA) { q.x = min(q.x, hi.x - p.x); }
    if (lo.y > AA) { q.y = p.y - lo.y; }
    if (hi.y < frame.y - AA) { q.y = min(q.y, hi.y - p.y); }
    return 1.0 - smoothstep(SEAM - AA, SEAM + AA, min(q.x, q.y));
}

// The quadtree of one clip around p, the largest blocks of size s0: each block shows the mean of
// its four quadrants and splits while their colors spread more than thr, down to depth dmax. A
// block that just reaches the threshold or the depth is half split: it fades into its four
// children, so the blocks never pop. Thin dark seams, faded in by seam_fade, line the blocks.
fn tree(p: vec2f, s0: vec2f, incoming: bool, thr: f32, dmax: f32, seam_fade: f32, ratio: f32) -> vec4f {
    var s = s0;
    var col = vec4f(0.0);
    // The weight of the current level in the result: how much the blocks above it have split.
    var acc = 1.0;
    var seam = 0.0;
    for (var l = 0; l < LEVELS; l++) {
        let c = (floor(p / s) + 0.5) * s;
        let h = 0.25 * s;
        let a = img(c - h, incoming, ratio);
        let b = img(c + vec2f(h.x, -h.y), incoming, ratio);
        let d = img(c + vec2f(-h.x, h.y), incoming, ratio);
        let e = img(c + h, incoming, ratio);
        let mean = 0.25 * (a + b + d + e);
        let v = abs(a - mean) + abs(b - mean) + abs(d - mean) + abs(e - mean);
        let spread = dot(v, vec4f(0.0625));
        // The seams of the smallest blocks are fainter, so they never cover the picture with a dark mesh.
        seam = max(seam, acc * smoothstep(0.008, 0.04, s.y) * seam_line(p, s, ratio));
        var split = smoothstep(thr, 1.35 * thr + 0.003, spread) * smoothstep(0.2, 0.8, dmax - f32(l));
        if (l == LEVELS - 1) { split = 0.0; }
        col += acc * (1.0 - split) * mean;
        acc *= split;
        if (acc <= 0.0) { break; }
        s *= 0.5;
    }
    return vec4f(col.rgb * (1.0 - params.seams * seam_fade * seam), col.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Kept inside the frame, so the right and top edges stay in the last blocks.
    let p = clamp(vec2f(uv.x * ratio, uv.y), vec2f(0.0), vec2f(ratio, 1.0) - 1e-4);
    // u: 0 at the ends (the real clips), 1 in the middle (the biggest blocks).
    let u = 1.0 - abs(2.0 * progress - 1.0);
    let coarse = mix(u, u * u * (3.0 - 2.0 * u), 0.5);
    let thr = params.tolerance * (0.08 + 4.0 * coarse * coarse);
    let dmax = f32(LEVELS) * (1.0 - coarse) + 0.2;
    let seam_fade = smoothstep(0.0, 0.25, u);

    var s0 = vec2f(0.5 * ratio, 1.0 / floor(2.0 / ratio + 0.5));
    if (ratio >= 1.0) { s0 = vec2f(ratio / floor(2.0 * ratio + 0.5), 0.5); }
    let t = (progress - 0.4) / 0.2;
    let cell = floor(p / s0);
    let h = fract((cell.y * floor(ratio / s0.x + 0.5) + cell.x) * 0.618034 + 0.31);
    let flip = smoothstep(0.75 * h, 0.75 * h + 0.25, t);
    var col: vec4f;
    if (flip <= 0.0) {
        col = tree(p, s0, false, thr, dmax, seam_fade, ratio);
    } else if (flip >= 1.0) {
        col = tree(p, s0, true, thr, dmax, seam_fade, ratio);
    } else {
        col = mix(tree(p, s0, false, thr, dmax, seam_fade, ratio), tree(p, s0, true, thr, dmax, seam_fade, ratio), flip);
    }
    var real = to_color(uv);
    if (progress < 0.5) { real = from_color(uv); }
    return mix(real, col, smoothstep(0.0, 0.18, u));
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
