// Port of TileBlast.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TileBlast.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Distance of the eye, and depth reached by a tile at the end of its flight, in frame heights.
const EYE: f32 = 2.0;
const ZEND: f32 = 1.6;
// How far a tile drifts away from the blast point while it flies.
const DRIFT: f32 = 0.3;
// A tile leaves after WAVE times its distance to the blast point (plus up to JITTER) and flies
// for FLIGHT, or faster after FINAL so every tile is gone at the end.
const WAVE: f32 = 0.75;
const JITTER: f32 = 0.06;
const FLIGHT: f32 = 0.45;
const FINAL: f32 = 0.75;
const EDGE: f32 = 0.0015;
// Direction toward the light, upper left, and the half vector between it and the eye.
const L: vec3f = vec3f(-0.32, 0.4, 0.86);
const HV: vec3f = vec3f(-0.1659, 0.2073, 0.9641);

fn hash4(p: vec2f) -> vec4f {
    var q = fract(vec4f(p.x, p.y, p.x, p.y) * vec4f(0.1031, 0.1030, 0.0973, 0.1099));
    q += dot(q, q.wzxy + 33.33);
    return fract((q.xxyz + q.yzzw) * q.zywx);
}

// How far the tile of cell g is along its flight, 0 at rest to 1 gone.
fn flight(g: vec2f, size: vec2f, c: vec2f, dmax: f32, progress: f32) -> f32 {
    let d = clamp((length((g + 0.5) * size - c) - 0.7 * size.y) / dmax, 0.0, 1.0);
    var t = (progress - WAVE * d - JITTER * hash4(g).x) / FLIGHT;
    t = clamp(max(t, (progress - FINAL) / (1.0 - FINAL)), 0.0, 1.0);
    return t * (0.55 + 0.45 * t);
}

fn fly_dir(g: vec2f, size: vec2f, c: vec2f) -> vec2f {
    let v = (g + 0.5) * size - c;
    let l = length(v);
    // A tile right on the blast point flies off in a direction of its own.
    let a = 6.2831853 * hash4(g + 7.0).x;
    return select(vec2f(cos(a), sin(a)), v / l, l > 0.02 * size.y);
}

// Rodrigues rotation of v around the unit axis k, by the angle of cosine cb and sine sb.
fn turn(v: vec3f, k: vec3f, cb: f32, sb: f32) -> vec3f {
    return v * cb + cross(k, v) * sb + k * dot(k, v) * (1.0 - cb);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let aspect = vec2f(ratio, 1.0);
    let pp = uv * aspect;
    // `center` is given y down.
    let c = clamp(vec2f(params.center.x, 1.0 - params.center.y), vec2f(0.0), vec2f(1.0)) * aspect;
    let n = clamp(f32(params.rows), 1.0, 12.0);
    let grid = vec2f(max(1.0, floor(ratio * n + 0.5)), n);
    let size = aspect / grid;
    let dmax = max(length(max(c, aspect - c) - 0.5 * size) - 0.7 * size.y, 1e-3);
    let spin_amt = clamp(params.spin, 0.0, 1.0);
    let shade_amt = clamp(params.shading, 0.0, 1.0);
    let eye = vec3f(c, EYE);
    let ray = vec3f(pp - c, -EYE);
    // The two nearest tiles seen here: depth, cell, picture point, coverage, shading.
    var z1 = 1e9;
    var z2 = 1e9;
    var g1 = vec2f(-1e4);
    var g2 = vec2f(-1e4);
    var q1 = pp;
    var q2 = pp;
    var m1 = 0.0;
    var m2 = 0.0;
    var s1 = 1.0;
    var s2 = 1.0;
    var lift1 = 0.0;
    var lift2 = 0.0;
    // March along the flight: for each step, find where a tile seen here would have started,
    // and test the 2x2 cells nearest to it. The steps move the start by less than half a tile.
    let dw = max(0.4 * size.y / (length(pp - c) * ZEND / EYE + DRIFT), 1.0 / 31.0);
    var last_cell = vec2f(-1e4);
    var last_side = vec2f(0.0);
    for (var k = 0; k < 32; k++) {
        var wk = f32(k) * dw;
        if (wk > 1.0 + dw) { break; }
        wk = min(wk, 1.0);
        let back = c + (pp - c) * (EYE - ZEND * wk) / EYE;
        var home = back - DRIFT * wk * fly_dir(floor(back / size), size, c);
        home = back - DRIFT * wk * fly_dir(floor(home / size), size, c);
        let f = home / size;
        let cell = floor(f);
        let side = step(vec2f(0.5), fract(f)) * 2.0 - 1.0;
        // Consecutive steps often land on the same cells.
        if (all(cell == last_cell) && all(side == last_side)) { continue; }
        last_cell = cell;
        last_side = side;
        for (var j = 0; j < 4; j++) {
            let g = cell + vec2f(select(0.0, side.x, j == 1 || j == 3), select(0.0, side.y, j >= 2));
            if (g.x < 0.0 || g.y < 0.0 || g.x >= grid.x || g.y >= grid.y) { continue; }
            if (all(g == g1) || all(g == g2)) { continue; }
            let u = flight(g, size, c, dmax, progress);
            if (u >= 1.0) { continue; }
            let h = hash4(g + 31.0);
            let dir = fly_dir(g, size, c);
            let h0 = (g + 0.5) * size;
            let tc = vec3f(h0 + dir * DRIFT * u, ZEND * u);
            let a = spin_amt * 2.4 * (h.x - 0.5) * u;
            let b = spin_amt * (0.5 + 0.7 * h.y) * select(1.0, -1.0, h.z < 0.5) * 1.8 * u;
            let ax = normalize(vec3f(-dir.y + 0.4 * (h.w - 0.5), dir.x, 0.0));
            let ca = cos(a);
            let sa = sin(a);
            let cb = cos(b);
            let sb = sin(b);
            let a1 = turn(vec3f(ca, sa, 0.0), ax, cb, sb);
            let a2 = turn(vec3f(-sa, ca, 0.0), ax, cb, sb);
            let nrm = turn(vec3f(0.0, 0.0, 1.0), ax, cb, sb);
            let den = dot(ray, nrm);
            if (abs(den) < 1e-5) { continue; }
            let lam = dot(tc - eye, nrm) / den;
            if (lam <= 0.0 || lam >= z2) { continue; }
            let hit = eye + lam * ray - tc;
            let l = vec2f(dot(hit, a1), dot(hit, a2));
            // Anti-aliased edges, scaled to the screen; hard at rest so the tiles join without seams.
            let bx = 0.5 * size - abs(l);
            let e = min(bx.x, bx.y) * EYE / (EYE - tc.z) * max(abs(nrm.z), 0.15);
            let m = clamp(e / (2.0 * EDGE) + 0.5 + 0.5 * (1.0 - smoothstep(0.0, 0.06, u)), 0.0, 1.0);
            if (m <= 0.0) { continue; }
            let nf = select(-nrm, nrm, den < 0.0);
            var lit = 1.0 - 0.6 * shade_amt * (1.0 - clamp(dot(nf, L) / L.z, 0.0, 1.0));
            let lift = smoothstep(0.0, 0.15, u);
            lit += shade_amt * lift * (0.2 * pow(max(dot(nf, HV), 0.0), 60.0) + 0.3 * (1.0 - smoothstep(0.0, 0.003, e)));
            if (den >= 0.0) { lit *= 0.55; }
            if (lam < z1) {
                z2 = z1; g2 = g1; q2 = q1; m2 = m1; s2 = s1; lift2 = lift1;
                z1 = lam; g1 = g; q1 = h0 + l; m1 = m; s1 = lit; lift1 = lift;
            } else {
                z2 = lam; g2 = g; q2 = h0 + l; m2 = m; s2 = lit; lift2 = lift;
            }
        }
    }
    var sh_to = 0.0;
    var sh1 = 0.0;
    var sh2 = 0.0;
    if (shade_amt > 0.0) {
        let base = floor(pp / size);
        for (var y = -1; y <= 1; y++) {
            for (var x = -1; x <= 1; x++) {
                let g = base + vec2f(f32(x), f32(y));
                if (g.x < 0.0 || g.y < 0.0 || g.x >= grid.x || g.y >= grid.y) { continue; }
                let u = flight(g, size, c, dmax, progress);
                let z = ZEND * u;
                // The shadow fades before it can reach beyond the next tile.
                let w = smoothstep(0.0, 0.03, u) * (1.0 - smoothstep(0.1 * size.y, 0.7 * size.y, z));
                if (w <= 0.0) { continue; }
                let o = pp + L.xy / L.z * z - ((g + 0.5) * size + fly_dir(g, size, c) * DRIFT * u);
                let blur = 0.004 + 0.25 * z;
                let sbx = 0.5 * size - abs(o) + 0.5 * blur;
                let sh = smoothstep(0.0, blur, sbx.x) * smoothstep(0.0, blur, sbx.y) * w;
                // A tile casts no shadow on itself.
                sh_to = max(sh_to, sh);
                if (any(g != g1)) { sh1 = max(sh1, sh); }
                if (any(g != g2)) { sh2 = max(sh2, sh); }
            }
        }
    }
    let dark = 0.5 * shade_amt;
    let settle = 1.0 - progress;
    let tq = c + (pp - c) / (1.0 + 0.06 * settle * settle);
    var col = to_color(tq / aspect);
    col = vec4f(col.rgb * (1.0 - dark * sh_to) * (1.0 - 0.25 * shade_amt * (1.0 - smoothstep(0.2, 0.9, progress))), col.a);
    if (m2 > 0.0) {
        var img = from_color(clamp(q2 / aspect, vec2f(0.0), vec2f(1.0)));
        img = vec4f(img.rgb * s2 * mix(1.0 - dark * sh2, 1.0, lift2), img.a);
        col = mix(col, img, m2);
    }
    if (m1 > 0.0) {
        var img = from_color(clamp(q1 / aspect, vec2f(0.0), vec2f(1.0)));
        img = vec4f(img.rgb * s1 * mix(1.0 - dark * sh1, 1.0, lift1), img.a);
        col = mix(col, img, m1);
    }
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
