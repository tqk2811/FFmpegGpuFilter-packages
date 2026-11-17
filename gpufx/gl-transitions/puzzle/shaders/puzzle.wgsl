// Port of Puzzle.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Puzzle.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Hash of a cell, without sin, in [0, 1).
fn hash(c: vec2f) -> f32 {
    var p = fract(c * vec2f(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}

fn box_dist(p: vec2f, half_size: vec2f) -> f32 {
    let q = abs(p) - half_size;
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0);
}

// Signed distance of a point, relative to the center of piece c, to that piece (cell units).
// Each inner edge has a knob: a tab for one piece, a blank for its neighbor.
fn piece_dist(p: vec2f, c: vec2f, grid: vec2f, aspect: f32) -> f32 {
    let half_size = vec2f(0.5 * aspect, 0.5);
    var d = box_dist(p, half_size);
    var tabs = 1e3;
    for (var e = 0; e < 4; e++) {
        var dir = vec2f(0.0, -1.0);
        if (e == 0) { dir = vec2f(1.0, 0.0); } else if (e == 1) { dir = vec2f(-1.0, 0.0); } else if (e == 2) { dir = vec2f(0.0, 1.0); }
        let key = c + min(dir, vec2f(0.0));
        let next = c + dir;
        if (next.x >= 0.0 && next.y >= 0.0 && next.x < grid.x && next.y < grid.y) {
            let h = hash(key + select(vec2f(71.0, 37.0), vec2f(0.0), e < 2));
            // The knob points right or up from the key cell when h < 0.5.
            let tab = (h < 0.5) == (dir.x + dir.y > 0.0);
            let out1 = dir * select(-1.0, 1.0, tab);
            let along = vec2f(abs(dir.y), abs(dir.x));
            let edge = dir * half_size + along * (fract(h * 2.0) - 0.5) * 0.16;
            let k = min(length(p - edge - out1 * 0.15) - 0.125, box_dist(p - edge - out1 * 0.06, abs(dir) * 0.08 + along * 0.085));
            if (tab) { tabs = min(tabs, k); } else { d = max(d, -k); }
        }
    }
    return min(d, tabs);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let pieces = params.pieces;
    // A grid of nearly square cells that fits the frame exactly.
    let rows = select(pieces, floor(pieces / ratio + 0.5), ratio < 1.0);
    let cols = select(floor(pieces * ratio + 0.5), pieces, ratio < 1.0);
    let grid = vec2f(cols, rows);
    let aspect = ratio * rows / cols;
    let g = uv * grid;
    let cell = floor(g);
    let aa = 0.01;
    var board_sum = 0.0;
    var all_sum = 0.0;
    var prio1 = -1.0;
    var prio2 = -1.0;
    var cov1 = 0.0;
    var cov2 = 0.0;
    var shade1 = 1.0;
    var shade2 = 1.0;
    var uv1 = uv;
    var uv2 = uv;
    var shadow_all = 0.0;
    var seam = 1.0;
    for (var i = 0; i < 9; i++) {
        let c = cell + vec2f(f32(i % 3), f32(i / 3)) - 1.0;
        if (c.x < 0.0 || c.y < 0.0 || c.x >= cols || c.y >= rows) { continue; }
        let center = c + 0.5;
        let local = (g - center) * vec2f(aspect, 1.0);
        let h = hash(c + vec2f(13.0, 7.0));
        let diag = (c.x / max(cols - 1.0, 1.0) + (rows - 1.0 - c.y) / max(rows - 1.0, 1.0)) * 0.5;
        let delay = (diag + 1.2 * (h - 0.5) * diag * (1.0 - diag)) * 0.6;
        let t = clamp((progress - delay) / 0.4, 0.0, 1.0);
        let d0 = piece_dist(local, c, grid, aspect);
        let w = 1.0 - smoothstep(-aa, aa, d0);
        all_sum += w;
        if (t <= 0.0) {
            board_sum += w;
            seam = min(seam, abs(d0));
            continue;
        }
        let lift = smoothstep(0.0, 0.25, t);
        board_sum += w * (1.0 - smoothstep(0.0, 0.1, t));
        var fall = clamp((t - 0.2) / 0.8, 0.0, 1.0);
        fall *= fall;
        let s = max(1.0 - fall, 0.001);
        let a = (h - 0.5) * 3.0 * fall;
        let off = vec2f(0.0, -1.2 * fall);
        let rot = mat2x2f(cos(a), -sin(a), sin(a), cos(a));
        let pl = rot * (local - off) / s;
        let dp = piece_dist(pl, c, grid, aspect);
        // Fades when tiny.
        let cov = (1.0 - smoothstep(-aa, aa, dp * s)) * min(s * 20.0, 1.0);
        let shade = (1.0 - 0.5 * fall) * (1.0 - 0.3 * lift * (1.0 - smoothstep(0.0, 0.035, -dp)));
        let puv = (center + pl / vec2f(aspect, 1.0)) / grid;
        let sl = rot * (local - off - vec2f(0.08, -0.1) * lift) / s;
        let sh = (1.0 - smoothstep(-0.05, 0.12, piece_dist(sl, c, grid, aspect) * s)) * lift * (1.0 - fall) * params.shadow;
        shadow_all = max(shadow_all, max(sh, w * lift * (1.0 - smoothstep(0.2, 0.5, t)) * params.shadow));
        if (cov > 0.0 && delay > prio1) {
            prio2 = prio1; cov2 = cov1; uv2 = uv1; shade2 = shade1;
            prio1 = delay; cov1 = cov; uv1 = puv; shade1 = shade;
        } else if (cov > 0.0 && delay > prio2) {
            prio2 = delay; cov2 = cov; uv2 = puv; shade2 = shade;
        }
    }
    var base = mix(to_color(uv), from_color(uv), board_sum / max(all_sum, 0.001));
    base = vec4f(base.rgb * (1.0 - shadow_all) * (1.0 - 0.4 * smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.0, 0.015, seam))), base.a);
    var p2 = from_color(uv2);
    p2 = vec4f(p2.rgb * shade2, p2.a);
    var p1 = from_color(uv1);
    p1 = vec4f(p1.rgb * shade1, p1.a);
    return mix(mix(base, p2, cov2), p1, cov1);
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
