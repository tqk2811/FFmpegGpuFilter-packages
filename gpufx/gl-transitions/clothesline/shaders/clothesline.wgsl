// Port of Clothesline.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Clothesline.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The original's `direction` (1 or -1) is the `reverse` switch here.
const FOCAL: f32 = 2.0; // distance from the camera to a print when it fills the frame
const GAP: f32 = 0.35;
const WALL: f32 = 0.14;
const ROPE: f32 = 0.0055;
const PIN: vec2f = vec2f(0.021, 0.072);
const PIN_Y: f32 = -0.01; // center of a clothespin below the top edge of its print
const AA: f32 = 0.0015;
const LIGHT: vec3f = vec3f(-0.28, 0.48, 0.83); // toward the light: above, a bit on the left, in front
const PIN_X: f32 = 0.32; // clothespins from the center of their print, in print widths
const STEPS: i32 = 32;

const SLIDE_START: f32 = 0.1;
const SLIDE_END: f32 = 0.86;

var<private> g_ratio: f32;

fn premultiply(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn slide_time(p: f32) -> f32 {
    return clamp((p - SLIDE_START) / (SLIDE_END - SLIDE_START), 0.0, 1.0);
}

fn slide_amount(u: f32) -> f32 {
    return u * u * u * (u * (u * 6.0 - 15.0) + 10.0);
}

fn slide_accel(p: f32) -> f32 {
    let u = slide_time(p);
    let dur = SLIDE_END - SLIDE_START;
    return 60.0 * u * (1.0 - u) * (1.0 - 2.0 * u) / (dur * dur);
}

// The sideways swing of the prints' bottoms, along the travel: a damped pendulum driven by the
// line's acceleration, lagging behind it at the start and overshooting at the stop.
fn swing(p: f32) -> f32 {
    let omega = 10.0; // about 1.6 swings over the transition
    let damp = 0.28;
    let st = 1.0 / f32(STEPS);
    var x = 0.0;
    var v = 0.0;
    // Fixed steps, the last one cut at p, so that every frame follows the same curve.
    for (var i = 0; i < STEPS; i++) {
        let t0 = f32(i) * st;
        let dt = clamp(p - t0, 0.0, st);
        let a = slide_accel(t0 + 0.5 * dt) - omega * omega * x - 2.0 * damp * omega * v;
        v += a * dt;
        x += v * dt;
    }
    return x * (1.0 - smoothstep(0.7, 1.0, p));
}

fn rounded_box(q: vec2f, b: vec2f, r: f32) -> f32 {
    let d = abs(q) - b + r;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// The point (u across, v down from the top edge) where the ray o + t d meets the plane of a print
// hanging from (cx, 0.5, 0) and swung back by psi around its top edge, and t.
fn print_hit(o: vec3f, d: vec3f, cx: f32, psi: f32) -> vec3f {
    let dn = vec3f(0.0, -cos(psi), -sin(psi));
    let n = vec3f(0.0, sin(psi), -cos(psi));
    let p0 = vec3f(cx, 0.5, 0.0);
    let t = dot(p0 - o, n) / dot(d, n);
    let q = o + d * t - p0;
    return vec3f(q.x, dot(q, dn), t);
}

fn bend_shift(v: f32, bend: f32) -> f32 {
    let h = clamp(v, 0.0, 1.0);
    return bend * h * (0.6 + 0.4 * h);
}

fn paper_dist(uv: vec2f, bend: f32) -> f32 {
    let q = abs(vec2f(uv.x - bend_shift(uv.y, bend), uv.y - 0.5)) - vec2f(0.5 * g_ratio, 0.5);
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0);
}

fn pin_dist(uv: vec2f) -> f32 {
    let q = vec2f(abs(uv.x) - PIN_X * g_ratio, uv.y - PIN_Y);
    return rounded_box(q, PIN, 0.012);
}

fn draw_print(col: vec4f, h: vec3f, is_from: bool, bend: f32, psi: f32, aa: f32, vis: f32) -> vec4f {
    let lp = h.xy;
    let d = paper_dist(lp, bend);
    let cov = clamp(0.5 - d / (h.z * aa), 0.0, 1.0);
    if (cov > 0.0) {
        let st = clamp(vec2f((lp.x - bend_shift(lp.y, bend)) / g_ratio + 0.5, 1.0 - lp.y), vec2f(0.0), vec2f(1.0));
        var c = premultiply(to_color(st));
        if (is_from) { c = premultiply(from_color(st)); }
        var shade = 1.0 - 1.2 * abs(sin(psi)) * lp.y - 0.35 * abs(bend) * lp.y;
        let ps = pin_dist(lp - vec2f(0.006, 0.01));
        shade -= 0.35 * vis * (1.0 - smoothstep(-0.004, 0.012, ps));
        c = vec4f(c.rgb * clamp(shade, 0.0, 1.0), c.a);
        return c * cov + col * (1.0 - c.a * cov);
    }
    return col;
}

fn draw_pins(col: vec4f, h: vec3f, aa: f32, vis: f32) -> vec4f {
    let lp = h.xy;
    let d = pin_dist(lp);
    let cov = vis * clamp(0.5 - d / (h.z * aa), 0.0, 1.0);
    if (cov > 0.0) {
        let k = clamp((abs(lp.x) - PIN_X * g_ratio) / PIN.x, -1.0, 1.0);
        var c = params.pin_color.rgb * (0.62 + 0.45 * sqrt(1.0 - k * k));
        let y = lp.y - PIN_Y;
        let spring = 1.0 - smoothstep(0.004, 0.007, abs(y + 0.02));
        c = mix(c, vec3f(0.3, 0.31, 0.33) * (0.6 + 0.8 * sqrt(1.0 - k * k)), spring);
        c *= 1.0 - 0.3 * (1.0 - smoothstep(0.002, 0.005, abs(y - 0.012)));
        let pc = premultiply(vec4f(c, params.pin_color.a));
        return pc * cov + col * (1.0 - pc.a * cov);
    }
    return col;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_ratio = globals.size.x / globals.size.y;
    let ratio = g_ratio;
    let p = progress;
    let s = select(1.0, -1.0, params.reverse != 0u);
    let sw = clamp(params.sway, 0.0, 1.0);

    let back = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.6, 1.0, p));
    let zoom = mix(1.0, clamp(params.size, 0.1, 1.0), back);
    let vis = smoothstep(0.0, 0.35, back);
    let o = vec3f(0.0, 0.05 * back, FOCAL / zoom);
    let d = vec3f((uv - 0.5) * vec2f(ratio, 1.0), -FOCAL);
    let aa = max(AA * min(1.0, 40.0 * back), 1e-6);

    let u = slide_time(p);
    let m = slide_amount(u);
    let speed = 16.0 * u * u * (1.0 - u) * (1.0 - u);
    let spacing = ratio + GAP;
    let c_from = -s * spacing * m;
    let c_to = s * spacing * (1.0 - m);
    let bend = s * 0.65 * sw * swing(p);
    let psi = 0.45 * sw * speed;

    let hf = print_hit(o, d, c_from, psi);
    let ht = print_hit(o, d, c_to, psi);

    var col = premultiply(params.background);
    let cover = max(
        clamp(0.5 - paper_dist(hf.xy, bend) / (hf.z * aa), 0.0, 1.0),
        clamp(0.5 - paper_dist(ht.xy, bend) / (ht.z * aa), 0.0, 1.0));
    col *= mix(1.0, back, cover);
    if (back > 0.0) {
        let w = o + d * ((o.z + WALL) / FOCAL);
        let sf = print_hit(w, LIGHT, c_from, psi);
        let st = print_hit(w, LIGHT, c_to, psi);
        let blur = 0.025;
        var sh = 1.0 - smoothstep(-blur, blur, min(paper_dist(sf.xy, bend), paper_dist(st.xy, bend)));
        sh = max(sh, 1.0 - smoothstep(-0.012, 0.02, min(pin_dist(sf.xy), pin_dist(st.xy))));
        let ry = w.y + LIGHT.y * (WALL / LIGHT.z) - (0.5 - 0.012);
        sh = max(sh, 0.8 * (1.0 - smoothstep(0.0, 0.012, abs(ry))));
        let fall = 0.1 * clamp(length(w.xy - vec2f(-0.4 * ratio, 0.6)) / (1.2 * ratio + 0.6), 0.0, 1.0);
        col = vec4f(col.rgb * (1.0 - 0.42 * vis * sh) * (1.0 - fall * vis), col.a);
    }

    col = draw_print(col, hf, true, bend, psi, aa, vis);
    col = draw_print(col, ht, false, bend, psi, aa, vis);

    if (vis > 0.0) {
        let tl = (o.z - 0.004) / FOCAL;
        let ly = o.y + d.y * tl - (0.5 - 0.012);
        let lc = vis * clamp(0.5 - (abs(ly) - ROPE) / (tl * aa), 0.0, 1.0);
        if (lc > 0.0) {
            let k = clamp(ly / ROPE, -1.0, 1.0);
            let lx = o.x + d.x * tl + s * spacing * m;
            let strand = 0.88 + 0.12 * sin((lx + ly * 0.6) * 360.0);
            let c = params.line_color.rgb * (0.7 + 0.45 * sqrt(1.0 - k * k) + 0.15 * k) * strand;
            let lcp = premultiply(vec4f(c, params.line_color.a));
            col = lcp * lc + col * (1.0 - lcp.a * lc);
        }
        col = draw_pins(col, hf, aa, vis);
        col = draw_pins(col, ht, aa, vis);
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
