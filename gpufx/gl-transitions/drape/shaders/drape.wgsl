// Port of Drape.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Drape.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const STEPS: i32 = 24;
const DEPTH: f32 = 0.8; // height of the deepest folds, times the fold width

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// Integer-free hash of an integer cell, smoothed into a 1D value noise in 0..1.
fn hash11(p0: f32) -> f32 {
    var p = fract(p0 * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

fn noise1(x: f32) -> f32 {
    let i = floor(x);
    let f = x - i;
    return mix(hash11(i), hash11(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// Height of the top edge above x, sagging in the middle (m: see cloth).
fn top_edge(x: f32, m: vec4f) -> f32 {
    let c = 2.0 * x - 1.0;
    return m.y - 0.08 * m.x * (1.0 - c * c);
}

fn side_pull(sy: f32, g_t: f32) -> f32 {
    return 0.035 * g_t * (0.3 + 0.7 * clamp(sy, 0.0, 1.0));
}

// Height of the cloth at the point (x, y) of the screen plane, toward the viewer, or -1 where
// there is no cloth. Also gives the cloth's own coordinates and fold phase.
// m: how far the folds have formed (0 at rest), height of the top edge, height of the hem, sideways swing.
fn cloth(p: vec2f, m: vec4f, fold_n: f32) -> vec4f {
    let g_t = m.x;
    let bot_y = m.z;
    let x = p.x - m.w;
    let top = top_edge(x, m);
    let sy = (p.y - bot_y) / max(top - bot_y, 1e-4); // 0 at the hem, 1 at the top edge
    let pull = side_pull(sy, g_t);
    let xc = (x - pull) / (1.0 - 2.0 * pull);
    let wander = (noise1(0.5 * fold_n * xc + 2.5 * sy + 5.3) - 0.5) * 2.4 * (1.0 - sy);
    let ph = 2.0 * PI * (fold_n * xc + 0.6 * noise1(0.7 * fold_n * xc + 1.7)) + wander;
    let d = 0.15 + 0.85 * noise1(1.1 * fold_n * xc + 1.4 * sy + 7.0);
    var amp = DEPTH * params.depth * g_t * (0.3 + 0.7 * sy * sqrt(max(sy, 0.0))) / max(fold_n, 2.0);
    let w = 0.6 / fold_n;
    amp *= smoothstep(0.0, w, xc) * smoothstep(0.0, w, 1.0 - xc);
    let prof = 0.5 - 0.5 * cos(ph); // 1 on a ridge, 0 in a valley
    let dt = (1.0 - sy) * (top - bot_y);
    let crease = exp(-30.0 * dt) * (0.5 + 0.5 * sin(80.0 * dt + 0.7 * ph));
    let on = sy >= 0.0 && sy <= 1.0 && xc >= 0.0 && xc <= 1.0;
    if (on) { return vec4f(amp * (d * prof + 0.15 * crease), xc, sy, ph); }
    return vec4f(-1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let depth = params.depth;
    let sway = params.sway;
    let t = progress;
    let top_y = 1.0 - 1.06 * t * (0.35 + 0.65 * t);
    let bot_y = -0.75 * t * t * t;
    let f = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
    let fold_n = max(1.0, floor(params.folds * min(ratio, 1.0) + 0.5));
    let shift_x = sway * 0.035 * sin(2.0 * PI * t) * f;
    // The cloth is seen a little from the left and from above: ridges hide the valleys behind them.
    let view = vec2f(0.75 + 0.5 * sway * sin(PI * t) * f, -0.35);
    let z_max = 1.15 * DEPTH * depth * f / max(fold_n, 2.0); // a single fold is no deeper than two
    let m = vec4f(f, top_y, bot_y, shift_x);
    // March from the front toward the screen plane, the first point inside the cloth is visible.
    var z_a = z_max; // last step in front of the cloth
    var z_b = 0.0; // first step inside it
    var found = false;
    var d_a = 0.0;
    var d_b = 0.0;
    var on_a = false; // whether the last step in front was over the cloth (else the ray came in through its edge)
    for (var i = 0; i < STEPS; i++) {
        if (!found) {
            let z = max(z_max * (1.0 - f32(i) / f32(STEPS - 1)), 0.0);
            let s = cloth(uv - view * z, m, fold_n);
            let dz = s.x - z;
            if (s.x >= 0.0 && dz >= 0.0) {
                found = true;
                z_b = z;
                d_b = dz;
            } else {
                z_a = z;
                d_a = dz;
                on_a = s.x >= 0.0;
            }
        }
    }
    var z_hit = z_b;
    if (found && z_a > z_b) {
        if (on_a) {
            z_hit = mix(z_a, z_b, d_a / (d_a - d_b));
        } else {
            // Came in through the top edge: find where the ray first meets the cloth, on its
            // surface or through the edge (then it sees the inside of the fold).
            var za = z_a;
            for (var j = 0; j < 5; j++) {
                let zm = 0.5 * (za + z_hit);
                if (cloth(uv - view * zm, m, fold_n).x >= zm) { z_hit = zm; } else { za = zm; }
            }
        }
    }
    var hp = uv - view * z_hit;
    var hit = vec4f(-1.0);
    if (found) { hit = cloth(hp, m, fold_n); }
    if (found && hit.x < 0.0) {
        z_hit = z_b;
        hp = uv - view * z_b;
        hit = cloth(hp, m, fold_n);
    }
    var col = vec4f(0.0);
    var cover = 0.0;
    if (hit.x >= 0.0) {
        let xc = hit.y;
        let sy = hit.z;
        let ph = hit.w;
        // The fabric is gathered: more of it goes into the slopes of the folds.
        let slope = PI * z_max * fold_n;
        // (Capped so that the texture never runs backwards where the folds bunch up.)
        let mu = min(0.25 * slope * slope / (1.0 + 0.25 * slope * slope), 0.5);
        let u = xc - mu * sin(2.0 * ph) / (4.0 * PI * fold_n);
        let h = max(top_y - bot_y, 1e-4);
        let comp = max(1.0 - h, 0.0);
        let v = sy * (1.0 - comp) + comp * sy * sy * sy;
        let tex = from_color(mirror(vec2f(u, v)));
        let span = top_edge(hp.x - shift_x, m) - bot_y;
        let e = 0.002;
        let hx = cloth(hp + vec2f(e, 0.0), m, fold_n).x;
        let hy = cloth(hp + vec2f(0.0, e), m, fold_n).x;
        let hx0 = select(hit.x, hx, hx >= 0.0);
        let hy0 = select(hit.x, hy, hy >= 0.0);
        let nrm = normalize(vec3f(-(hx0 - hit.x) / e, -(hy0 - hit.x) / e, 1.0));
        let light = normalize(vec3f(-0.45, 0.35, 1.0));
        let diffuse = mix(1.0, max(dot(nrm, light), 0.0) / light.z, min(1.0, 3.0 * f));
        let valley = 1.0 - (0.5 - 0.5 * cos(ph));
        let ao = 1.0 - 0.6 * depth * f * valley * valley * (0.35 + 0.65 * sy);
        let rim = exp(-(1.0 - sy) * span * 70.0) * 0.35 * f;
        // Below the surface, the ray sees the shaded inside of a fold through the top edge.
        let under = max(hit.x - z_hit, 0.0);
        let back = min(1.0, under / max(0.1 * z_max, 1e-6));
        col = vec4f(tex.rgb * diffuse * ao * (1.0 - rim) * (1.0 - 0.6 * back), tex.a);
        // Antialiased outline, sharp at rest so the first frame is exact.
        let aa = 0.003 * f;
        let inside = min((1.0 - sy) * span - view.y * under, min(xc, 1.0 - xc));
        cover = 1.0;
        if (aa > 0.0) { cover = clamp(inside / aa, 0.0, 1.0); }
        if (cover >= 1.0) { return col; }
    }
    let to = to_color(uv);
    let x = uv.x - shift_x;
    let pull = side_pull((uv.y - bot_y) / max(top_edge(x, m) - bot_y, 1e-4), f);
    let outside = max(uv.y - top_edge(x, m), max(-x, x - 1.0) - pull);
    let sh = params.shadow * exp(-max(outside, 0.0) * 16.0) * f * clamp(8.0 * (1.0 - t), 0.0, 1.0);
    return mix(vec4f(to.rgb * (1.0 - 0.8 * sh), to.a), col, cover);
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
