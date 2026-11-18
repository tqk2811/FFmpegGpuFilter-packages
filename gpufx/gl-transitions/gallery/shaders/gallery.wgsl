// Port of Gallery.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Gallery.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The original's `direction` (1 or -1) is the `reverse` switch here.
const FOCAL: f32 = 1.6; // distance from the camera to a slide when it fills the frame
const MAX_ANGLE: f32 = 1.4; // turn of a side slide at tilt = 1, in radians
const NEIGHBOUR: f32 = 0.3;
const AA: f32 = 0.002;

fn premultiply(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

// How far slide k sits from the center of the view, in slides, clamped to one slide on each side.
fn offset(k: f32, cam_q: f32, spacing: f32) -> f32 {
    return clamp((k * spacing - cam_q) / spacing, -1.0, 1.0);
}

// The ray o + t d against slide k of the row (a plane turned around its vertical axis): returns
// (u, v, t, coverage), coverage antialiased over aa frame heights at the slide's edges.
fn slide_hit(o: vec3f, d: vec3f, k: f32, s: f32, cam_q: f32, spacing: f32, aa: f32, ratio: f32) -> vec4f {
    let a = -s * MAX_ANGLE * params.tilt * offset(k, cam_q, spacing);
    let c = vec3f(s * k * spacing, 0.0, 0.0);
    let tg = vec3f(cos(a), 0.0, sin(a));
    let n = vec3f(-tg.z, 0.0, tg.x);
    let dn = dot(d, n);
    if (abs(dn) < 1e-5) { return vec4f(0.0, 0.0, -1.0, 0.0); }
    let t = dot(c - o, n) / dn;
    let q = o + d * t - c;
    let lx = dot(q, tg) + 0.5 * ratio;
    let ly = q.y + 0.5;
    // Distances to the edges on screen: along the slide, how fast its local x moves with the screen x.
    let jx = abs(t * (tg.x - dot(d, tg) * n.x / dn));
    let ex = min(lx, ratio - lx) / max(jx, 1e-6);
    let ey = min(ly, 1.0 - ly) / max(t, 1e-6);
    var cov = 0.0;
    if (t > 0.0) { cov = clamp(0.5 + min(ex, ey) / aa, 0.0, 1.0); }
    return vec4f(lx / ratio, ly, t, cov);
}

// The premultiplied color of slide k where the ray hit it; the row is the first clip (k = 0), the
// second (k = 1), and faint repeats beyond them on their own side; refl > 0 is the strength of its reflection.
fn slide_color(h: vec4f, k: f32, cam_q: f32, spacing: f32, refl: f32, bg: vec4f) -> vec4f {
    if (h.w <= 0.0) { return vec4f(0.0); }
    let st = clamp(h.xy, vec2f(0.0), vec2f(1.0));
    var c = premultiply(select(to_color(st), from_color(st), k < 0.5));
    c = vec4f(c.rgb * (1.0 - 0.3 * params.tilt * abs(offset(k, cam_q, spacing))), c.a);
    if (k < -0.5 || k > 1.5) { c = mix(bg, c, NEIGHBOUR); }
    var f = 1.0;
    if (refl > 0.0) { f = refl * (1.0 - smoothstep(0.0, 0.6, st.y)); }
    return c * (h.w * f);
}

// How much the slides cover along the ray, whatever their clips' alpha.
fn scene_cover(o: vec3f, d: vec3f, s: f32, cam_q: f32, spacing: f32, aa: f32, ratio: f32) -> f32 {
    let kc = floor(s * (o.x + d.x * o.z / -d.z) / spacing + 0.5);
    let w0 = slide_hit(o, d, kc - 1.0, s, cam_q, spacing, aa, ratio).w;
    let w1 = slide_hit(o, d, kc, s, cam_q, spacing, aa, ratio).w;
    let w2 = slide_hit(o, d, kc + 1.0, s, cam_q, spacing, aa, ratio).w;
    return 1.0 - (1.0 - w0) * (1.0 - w1) * (1.0 - w2);
}

// The slides seen along the ray, composited back to front (premultiplied).
fn scene(o: vec3f, d: vec3f, s: f32, cam_q: f32, spacing: f32, aa: f32, refl: f32, bg: vec4f, ratio: f32) -> vec4f {
    let wall_q = s * (o.x + d.x * o.z / -d.z);
    let kc = floor(wall_q / spacing + 0.5);
    let h0 = slide_hit(o, d, kc - 1.0, s, cam_q, spacing, aa, ratio);
    let h1 = slide_hit(o, d, kc, s, cam_q, spacing, aa, ratio);
    let h2 = slide_hit(o, d, kc + 1.0, s, cam_q, spacing, aa, ratio);
    var c0 = slide_color(h0, kc - 1.0, cam_q, spacing, refl, bg);
    var c1 = slide_color(h1, kc, cam_q, spacing, refl, bg);
    var c2 = slide_color(h2, kc + 1.0, cam_q, spacing, refl, bg);
    var t0 = select(1e6, h0.z, h0.w > 0.0);
    var t1 = select(1e6, h1.z, h1.w > 0.0);
    var t2 = select(1e6, h2.z, h2.w > 0.0);
    // Sort far to near: t0 >= t1 >= t2.
    var tc: vec4f;
    var tt: f32;
    if (t0 < t1) { tc = c0; c0 = c1; c1 = tc; tt = t0; t0 = t1; t1 = tt; }
    if (t1 < t2) { tc = c1; c1 = c2; c2 = tc; tt = t1; t1 = t2; t2 = tt; }
    if (t0 < t1) { tc = c0; c0 = c1; c1 = tc; }
    var col = c0;
    col = c1 + col * (1.0 - c1.a);
    col = c2 + col * (1.0 - c2.a);
    return col;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let s = select(1.0, -1.0, params.reverse != 0u);
    let spacing = ratio * (1.0 + params.gap);
    let back = smoothstep(0.0, 0.42, p) * (1.0 - smoothstep(0.58, 1.0, p));
    let m = clamp((p - 0.18) / 0.64, 0.0, 1.0);
    let glide = m * m * m * (m * (m * 6.0 - 15.0) + 10.0);
    let cam_q = spacing * glide;
    let o = vec3f(s * cam_q, 0.0, FOCAL * (1.0 + params.zoom * back));
    let d = vec3f((uv - 0.5) * vec2f(ratio, 1.0), -FOCAL);
    let amount = min(1.0, 40.0 * back);
    let aa = max(AA * amount, 1e-6);
    let bg = premultiply(params.background);

    var col = scene(o, d, s, cam_q, spacing, aa, 0.0, bg, ratio);
    if (col.a < 1.0) {
        var under = bg;
        if (d.y < 0.0 && params.reflection > 0.0) {
            let r = scene(vec3f(o.x, -1.0 - o.y, o.z), vec3f(d.x, -d.y, d.z), s, cam_q, spacing, aa, params.reflection, bg, ratio);
            under = r + bg * (1.0 - r.a);
        }
        // The wall shows around the slides, and only fades in behind their transparent parts,
        // so that the clips keep their own alpha at the start and the end.
        col += under * (mix(1.0, amount, scene_cover(o, d, s, cam_q, spacing, aa, ratio)) * (1.0 - col.a));
    }
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
