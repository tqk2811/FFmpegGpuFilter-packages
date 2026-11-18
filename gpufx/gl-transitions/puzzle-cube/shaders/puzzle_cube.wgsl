// Port of PuzzleCube.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PuzzleCube.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// Delay between the turns of a group, as a part of a turn.
const STAGGER: f32 = 0.45;
const EDGE: f32 = 0.0012;

var<private> g_progress: f32;
var<private> g_ratio: f32;

fn gl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn grid_size() -> f32 {
    return f32(clamp(params.size, 2, 8));
}

// The turns run in 3 groups, one after the other: the even columns, the even rows (counted from
// the top), then the odd columns; the turns of a group overlap.
fn group_length(m: f32) -> f32 {
    if (m > 0.0) { return 1.0 + (m - 1.0) * STAGGER; }
    return 0.0;
}

// The time in turn units, and the length of the groups of even and odd slices.
fn timeline(n: f32) -> vec3f {
    let len_even = group_length(floor((n + 1.0) * 0.5));
    let len_odd = group_length(floor(n * 0.5));
    let u = clamp((g_progress - 0.05) / 0.85, 0.0, 1.0) * (2.0 * len_even + len_odd);
    return vec3f(u, len_even, len_odd);
}

// The turn of a column (is_col) or of a row, 0 at rest to 1 turned.
fn turn_time(tl: vec3f, is_col: bool, idx: f32, n: f32) -> f32 {
    let k = select(n - 1.0 - idx, idx, is_col);
    let odd = gl_mod(k, 2.0) > 0.5;
    // The odd rows never turn: the columns already brought the second clip there.
    if (odd && !is_col) { return 0.0; }
    let start = select(select(tl.y, 0.0, is_col), 2.0 * tl.y, odd) + floor(k * 0.5) * STAGGER;
    return clamp(tl.x - start, 0.0, 1.0);
}

// The turn's direction: +1 brings the side of the cube at higher coordinates to the front.
fn turn_dir(is_col: bool, idx: f32) -> f32 {
    return select(-1.0, 1.0, gl_mod(idx + select(1.0, 0.0, is_col), 2.0) < 0.5);
}

// Eased angle, landing with a little speed left like a click.
fn turn_angle(t: f32) -> f32 {
    return 0.5 * PI * mix(t, t * t * (3.0 - 2.0 * t), 0.8);
}

// 1 on the cubies' faces, 0 in the gaps, at the point fp of the face (frame heights).
fn face_mask(fp: vec2f, n: f32, g: f32) -> f32 {
    if (g <= 0.0) { return 1.0; }
    let cell = vec2f(g_ratio, 1.0) / n;
    let c = fp / cell;
    let r = floor(c + 0.5);
    // Distance to the nearest cubie edge inside the face (the face's own border has no gap).
    var d = abs(c - r) * cell;
    if (r.x < 0.5 || r.x > n - 0.5) { d.x = 1.0; }
    if (r.y < 0.5 || r.y > n - 0.5) { d.y = 1.0; }
    let e = min(EDGE, 0.5 * g);
    return smoothstep(0.5 * g - e, 0.5 * g + e, min(d.x, d.y));
}

fn is_done(tl: vec3f, fp: vec2f, n: f32) -> bool {
    let cell = clamp(floor(fp / (vec2f(g_ratio, 1.0) / n)), vec2f(0.0), vec2f(n - 1.0));
    return turn_time(tl, true, cell.x, n) >= 1.0 || turn_time(tl, false, cell.y, n) >= 1.0;
}

fn sticker(fp: vec2f, incoming: bool, light: f32, n: f32, g: f32) -> vec4f {
    let uv = clamp(fp / vec2f(g_ratio, 1.0), vec2f(0.0), vec2f(1.0));
    var img = from_color(uv);
    if (incoming) { img = to_color(uv); }
    let body = vec4f(params.background.rgb * light, params.background.a);
    return mix(body, vec4f(img.rgb * light, img.a), face_mask(fp, n, g));
}

// Brightness of a face of normal nrm (across the slices, along the turn, depth) in the turn's
// space, 1 facing the viewer.
fn lighting(nrm: vec3f, is_col: bool) -> f32 {
    var l = normalize(vec3f(-0.35, 0.55, 1.0));
    if (is_col) { l = l.yxz; }
    return 1.0 - params.shading * (1.0 - clamp(dot(nrm, l) / l.z, 0.0, 1.0));
}

fn rot(v: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Casts the ray (o, d), in the turn's space (across the slices, along the turn, depth), onto the
// slice [a0, a0 + w] turned by the angle a around the middle of the cube (a square section of side
// s): returns the ray's parameter at the hit (or -1), the face hit (0 front, 1 back, 2 and 3 the
// sides at higher and lower coordinates along the turn at rest, 4 the slice's ends), and the point
// hit (across the slices, and across the face, -1 to 1).
fn slice_hit(o: vec3f, d: vec3f, a0: f32, w: f32, s: f32, a: f32) -> vec4f {
    let lo = rot(o.yz - vec2f(0.5 * s, -0.5 * s), -a);
    var ld = rot(d.yz, -a);
    ld = vec2f(select(ld.x, 1e-6, abs(ld.x) < 1e-6), select(ld.y, 1e-6, abs(ld.y) < 1e-6));
    let dx = select(d.x, 1e-6, abs(d.x) < 1e-6);
    let t1 = vec3f((a0 - o.x) / dx, (-0.5 * s - lo) / ld);
    let t2 = vec3f((a0 + w - o.x) / dx, (0.5 * s - lo) / ld);
    let tn = min(t1, t2);
    let tf = max(t1, t2);
    let t_near = max(tn.x, max(tn.y, tn.z));
    let t_far = min(tf.x, min(tf.y, tf.z));
    if (t_near > t_far || t_near <= 0.0) { return vec4f(-1.0); }
    let q = (lo + t_near * ld) / (0.5 * s);
    let across = o.x + t_near * d.x;
    if (tn.x >= tn.y && tn.x >= tn.z) { return vec4f(t_near, 4.0, across, sign(-dx)); }
    if (tn.y > tn.z) { return vec4f(t_near, select(3.0, 2.0, ld.x < 0.0), across, q.y); }
    return vec4f(t_near, select(1.0, 0.0, ld.y < 0.0), across, q.x);
}

fn slice_color(hit: vec4f, tl: vec3f, is_col: bool, a: f32, dir: f32, s: f32, n: f32, g: f32) -> vec4f {
    let bg = params.background;
    let f = hit.y;
    if (f > 3.5) { return vec4f(bg.rgb * lighting(vec3f(hit.w, 0.0, 0.0), is_col), bg.a); }
    var nl = vec2f(-1.0, 0.0);
    if (f < 0.5) { nl = vec2f(0.0, 1.0); } else if (f < 1.5) { nl = vec2f(0.0, -1.0); } else if (f < 2.5) { nl = vec2f(1.0, 0.0); }
    let light = lighting(vec3f(0.0, rot(nl, a)), is_col);
    // The front shows what the cubies showed before this turn, the side that comes to the front
    // shows the second clip where it lands.
    let front = f < 0.5;
    let coming = nl.x * dir > 0.5;
    if (!front && !coming) { return vec4f(bg.rgb * light, bg.a); }
    // On the side coming to the front, the point across lands at -dir times its depth.
    let r = 0.5 * s * (1.0 + select(-dir * hit.w, hit.w, front));
    let fp = select(vec2f(r, hit.z), vec2f(hit.z, r), is_col);
    return sticker(fp, coming || is_done(tl, fp, n), light, n, g);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    g_ratio = globals.size.x / globals.size.y;
    let ratio = g_ratio;
    let bg = params.background;
    let shading = params.shading;
    let n = grid_size();
    let tl = timeline(n);
    let g = params.gap * smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
    let pt = vec2f(uv.x * ratio, uv.y);

    // The turns going on are of columns or of rows, never both.
    let is_col = tl.x < tl.y || tl.x >= 2.0 * tl.y;
    // The turn's space: (across the slices, along the turn, depth toward the viewer); a column
    // turns around the horizontal axis through the middle of the cube, a row around the vertical one.
    let w = select(1.0, ratio, is_col) / n;
    let s = select(ratio, 1.0, is_col);
    let pp = select(pt.yx, pt, is_col);
    let o = vec3f(select(vec2f(0.5, 0.5 * ratio), vec2f(0.5 * ratio, 0.5), is_col), 1.2 + 0.6 * max(ratio, 1.0));
    // The ray reaches the face (z = 0) at t = 1.
    let d = vec3f(pp, 0.0) - o;

    let k0 = clamp(floor(pp.x / w), 0.0, n - 1.0);
    let t0 = turn_time(tl, is_col, k0, n);

    var nearest = 1.0;
    var color: vec4f;
    if (t0 <= 0.0 || t0 >= 1.0) {
        color = from_color(uv);
        if (is_done(tl, pt, n)) { color = to_color(uv); }
        color = mix(bg, color, face_mask(pt, n, g));
        for (var j = -1; j <= 1; j += 2) {
            let k = k0 + f32(j);
            if (k < 0.0 || k > n - 1.0) { continue; }
            let tk = turn_time(tl, is_col, k, n);
            if (tk <= 0.0 || tk >= 1.0) { continue; }
            let dist = abs(pp.x - (k + 0.5) * w) - 0.5 * w;
            color = vec4f(color.rgb * (1.0 - 0.5 * shading * sin(2.0 * turn_angle(tk)) * exp(-dist / (0.2 * w))), color.a);
        }
    } else {
        var tw = 1e6;
        if (abs(d.x) >= 1e-6) { tw = (select((k0 + 1.0) * w - o.x, k0 * w - o.x, d.x < 0.0)) / d.x; }
        let tb = (o.z + s) / -d.z;
        nearest = min(tw, tb);
        let along = o.y + nearest * d.y;
        let depth = (o.z + nearest * d.z) / -s;
        var light = 1.0;
        if (tw < tb) { light = lighting(vec3f(-sign(d.x), 0.0, 0.0), is_col); }
        light *= 1.0 - shading * (0.5 + 0.4 * clamp(depth, 0.0, 1.0));
        color = vec4f(bg.rgb * light, bg.a);
        if (along < 0.0 || along > s) { color = bg; }
    }

    for (var j = -1; j <= 1; j++) {
        let k = k0 + f32(j);
        if (k < 0.0 || k > n - 1.0) { continue; }
        let tk = turn_time(tl, is_col, k, n);
        if (tk <= 0.0 || tk >= 1.0) { continue; }
        let dir = turn_dir(is_col, k);
        let a = dir * turn_angle(tk);
        let hit = slice_hit(o, d, k * w, w, s, a);
        if (hit.x > 0.0 && hit.x < nearest) {
            nearest = hit.x;
            color = slice_color(hit, tl, is_col, a, dir, s, n, g);
        }
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
