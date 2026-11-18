// Port of StopMotion.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StopMotion.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SHRINK: f32 = 0.2; // how much smaller the cutouts are than the frame while they move
const RIM: f32 = 0.012;
const RADIUS: f32 = 0.006;
const AA: f32 = 0.0015;

// Hoskins' hash of an integer step.
fn hash11(p0: f32) -> f32 {
    var p = fract(p0 * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

fn rounded_box(q: vec2f, b: vec2f, r: f32) -> f32 {
    let d = abs(q) - b + r;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

fn premultiply(c: vec4f) -> vec4f {
    return vec4f(c.rgb * c.a, c.a);
}

// Distance from the center far enough for a cutout of half size h turned by a, and its shadow, to be out of the frame.
fn off_frame(h: vec2f, a: f32, ratio: f32) -> f32 {
    return 0.5 * ratio + abs(cos(a)) * h.x + abs(sin(a)) * h.y + 0.08;
}

// Half size of a cutout scaled by s, with its rim for the lift l.
fn cutout_size(s: f32, l: f32, ratio: f32) -> vec2f {
    return (0.5 * vec2f(ratio, 1.0) + RIM * l) * s;
}

fn clip_color(st: vec2f, incoming: bool) -> vec4f {
    if (incoming) { return to_color(st); }
    return from_color(st);
}

// Draws over col (premultiplied) a cutout of the first or second clip, centered at c, turned by a,
// scaled by s, lifted by l.
fn draw_cutout(col0: vec4f, q: vec2f, c: vec2f, a: f32, s: f32, l: f32, incoming: bool, ratio: f32) -> vec4f {
    let rim_color = params.rim_color;
    let asp = vec2f(ratio, 1.0);
    let half_image = 0.5 * asp;
    let half_cut = half_image + RIM * l;
    let rad = RADIUS * l;
    let ca = cos(a);
    let sa = sin(a);
    let unrotate = mat2x2f(ca, -sa, sa, ca);

    // The drop shadow, softer and further as the cutout is lifted, as dark as its picture is opaque.
    let rs = unrotate * (q - c - vec2f(0.018, -0.026) * l) / s;
    let ss = clamp(rs / asp + 0.5, vec2f(0.0), vec2f(1.0));
    let s_alpha = max(clip_color(ss, incoming).a, rim_color.a);
    let ds = rounded_box(rs, half_cut, rad) * s;
    let blur = 0.004 + 0.016 * l;
    let col = vec4f(col0.rgb * (1.0 - clamp(params.shadow, 0.0, 1.0) * 0.75 * l * s_alpha * (1.0 - smoothstep(-blur, blur, ds))), col0.a);

    let r = unrotate * (q - c) / s;
    let d_cut = rounded_box(r, half_cut, rad) * s;
    let d_image = rounded_box(r, half_image, 0.0) * s;
    let cut_cover = clamp(0.5 - d_cut / AA, 0.0, 1.0);
    let image_cover = clamp(0.5 - d_image / AA, 0.0, 1.0);
    let st = clamp(r / asp + 0.5, vec2f(0.0), vec2f(1.0));
    let img = premultiply(clip_color(st, incoming));
    let cut = mix(premultiply(rim_color), img, image_cover) * cut_cover;
    return cut + col * (1.0 - cut.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = f32(max(params.steps, 2));
    // The pose held at this time: the first and last are the full clips, held half a step each.
    let k = floor(progress * n + 0.5);
    if (k <= 0.0) { return from_color(uv); }
    if (k >= n) { return to_color(uv); }

    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let j = clamp(params.jitter, 0.0, 1.0);

    let l0 = min(k / 2.0, 1.0);
    var m0 = clamp((k - 1.0) / (0.45 * n), 0.0, 1.0);
    m0 = m0 * m0 * (0.4 + 0.6 * m0);
    let s0 = 1.0 - SHRINK * l0;
    let a0 = 0.22 * m0 + l0 * j * 0.2 * (hash11(k) - 0.5);
    let c0 = vec2f(-off_frame(cutout_size(s0, l0, ratio), a0, ratio) * m0, 0.05 * m0 * m0)
        + l0 * j * vec2f(0.07 * (hash11(k + 100.0) - 0.5), 0.05 * (hash11(k + 200.0) - 0.5));

    let l1 = min((n - k) / 2.0, 1.0);
    var m1 = clamp((n - 2.0 - k) / (0.45 * n), 0.0, 1.0);
    m1 = m1 * m1 * (0.4 + 0.6 * m1);
    let s1 = 1.0 - SHRINK * l1;
    let a1 = -0.25 * m1 + l1 * j * 0.2 * (hash11(k + 300.0) - 0.5);
    let c1 = vec2f(off_frame(cutout_size(s1, l1, ratio), a1, ratio) * m1, -0.06 * m1 * m1)
        + l1 * j * vec2f(0.07 * (hash11(k + 400.0) - 0.5), 0.05 * (hash11(k + 500.0) - 0.5));

    // The background, then the first cutout, then the second one on top.
    var col = premultiply(params.back_color);
    if (m0 < 1.0) { col = draw_cutout(col, q, c0, a0, s0, l0, false, ratio); }
    if (m1 < 1.0) { col = draw_cutout(col, q, c1, a1, s1, l1, true, ratio); }
    if (col.a <= 0.0) { return vec4f(0.0); }
    return vec4f(col.rgb / col.a * (1.0 - 0.04 * j * hash11(k + 600.0)), col.a);
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
