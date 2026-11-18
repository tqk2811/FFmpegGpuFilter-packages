// Port of InsideCube.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InsideCube.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.002;

fn premul(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn corner_shadow(dist: f32, size: f32) -> f32 {
    let k = 1.0 - smoothstep(0.0, size, dist);
    return k * k;
}

// The clip on a wall at point l of the wall, in frame heights from its center (l.x along the
// turn, l.y across), premultiplied; s and vertical undo the mirroring and swap of axes.
fn wall_color(l: vec2f, incoming: bool, vertical: bool, s: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let h = vec2f(l.x * s, l.y);
    let p = select(h, h.yx, vertical);
    let st = clamp(p / vec2f(ratio, 1.0) + 0.5, vec2f(0.0), vec2f(1.0));
    if (incoming) { return premul(to_color(st)); }
    return premul(from_color(st));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let vertical = abs(params.direction.y) > abs(params.direction.x);
    let s = select(1.0, -1.0, select(params.direction.x, params.direction.y, vertical) < 0.0);
    // q.x: along the turn, toward the incoming wall; q.y: across; in frame heights.
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    var q = select(p, p.yx, vertical);
    q.x *= s;
    let big_a = select(0.5 * ratio, 0.5, vertical);
    let big_b = select(0.5, 0.5 * ratio, vertical);
    let f = big_a / tan(radians(clamp(params.fov, 55.0, 170.0)) * 0.5);
    let e = smoothstep(0.0, 1.0, progress);
    let th = 0.5 * PI * e;
    let c = cos(th);
    let sn = sin(th);
    let amount = max(sin(PI * e), 0.0);
    let aa = EDGE * min(1.0, 40.0 * amount) + 1e-6;
    let shadow = shading * min(1.0, 4.0 * amount);
    // In the plane of the turn (a: along, z: depth) the outgoing wall is z = f, a in [-A, A],
    // the incoming wall is a = A, z in [f - 2A, f].
    let cam = (big_a - f) * e * vec2f(1.0, -1.0);
    let d = vec2f(q.x * c + f * sn, f * c - q.x * sn);
    let pp = vec2f(big_a, f) - cam;
    let sc = f * (pp.x * c - pp.y * sn) / max(pp.x * sn + pp.y * c, 1e-6);
    let tf = select(1e6, (f - cam.y) / d.y, d.y > 1e-6);
    let af = cam.x + tf * d.x;
    let lf = vec2f(af, q.y * tf);
    let ti = select(1e6, (big_a - cam.x) / d.x, d.x > 1e-6);
    let ai = (f - big_a) - (cam.y + ti * d.y);
    let li = vec2f(ai, q.y * ti);
    let size = 0.8 * min(big_a, big_b);
    let edge_f = corner_shadow(big_a - af, size) + 0.5 * corner_shadow(big_b - abs(lf.y), size);
    let edge_i = corner_shadow(ai + big_a, size) + 0.5 * corner_shadow(big_b - abs(li.y), size);
    let shade_f = (1.0 - shading * 0.8 * (1.0 - c)) * (1.0 - 0.7 * shadow * min(edge_f, 1.0));
    let shade_i = (1.0 - shading * 0.8 * (1.0 - sn)) * (1.0 - 0.7 * shadow * min(edge_i, 1.0));
    // Coverage of each wall: split at the corner line, cut by the wall edges.
    let w_f = clamp(0.5 + (sc - q.x) / aa, 0.0, 1.0);
    let cov_f = w_f * clamp(0.5 + (big_b / tf - abs(q.y)) / aa, 0.0, 1.0)
        * clamp(0.5 + (af + big_a) * d.y / (tf * f * aa), 0.0, 1.0);
    let cov_i = (1.0 - w_f) * clamp(0.5 + (big_b / ti - abs(q.y)) / aa, 0.0, 1.0)
        * clamp(0.5 + (big_a - ai) * d.x / (ti * f * aa), 0.0, 1.0);
    var col_f = vec4f(0.0);
    if (cov_f > 0.0) { col_f = wall_color(lf, false, vertical, s); }
    var col_i = vec4f(0.0);
    if (cov_i > 0.0) { col_i = wall_color(li, true, vertical, s); }
    col_f = vec4f(col_f.rgb * shade_f, col_f.a);
    col_i = vec4f(col_i.rgb * shade_i, col_i.a);
    var bg = premul(params.background);
    let cov = cov_f + cov_i;
    if (cov < 1.0) {
        let tb = min(big_b / max(abs(q.y), 1e-6), min(tf, ti));
        let fl = cam + tb * d;
        let edge_b = corner_shadow(f - fl.y, size) + corner_shadow(big_a - fl.x, size);
        bg = vec4f(bg.rgb * (1.0 - 0.5 * shadow * min(edge_b, 1.0)), bg.a);
    }
    let col = col_f * cov_f + col_i * cov_i + bg * (1.0 - cov);
    if (col.a > 0.0) { return vec4f(col.rgb / col.a, col.a); }
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
