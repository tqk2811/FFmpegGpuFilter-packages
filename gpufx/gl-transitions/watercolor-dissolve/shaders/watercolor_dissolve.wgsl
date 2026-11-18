// Port of WatercolorDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WatercolorDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

var<private> g_progress: f32;

fn wc_hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    // (Kept in 0..1 before the last product, so that its rounding is the same on every target.)
    p3 = fract(p3 + dot(p3, p3.yzx + 33.33));
    return fract((p3.x + p3.y) * p3.z * 37.0);
}

fn wc_noise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(wc_hash(i), wc_hash(i + vec2f(1.0, 0.0)), f.x),
        mix(wc_hash(i + vec2f(0.0, 1.0)), wc_hash(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

// 0..1, spread evenly over the range (the sum of the octaves is about normal, around 0.5).
fn wc_fbm(p0: vec2f) -> f32 {
    var p = p0;
    var v = 0.0;
    var a = 0.5;
    for (var i = 0; i < 4; i++) {
        v += a * wc_noise(p);
        p = mat2x2f(1.6, 1.2, -1.2, 1.6) * p + 5.7;
        a *= 0.5;
    }
    let z = (v / 0.9375 - 0.5) / 0.11;
    return 0.5 + 0.5 * z / sqrt(1.0 + z * z);
}

fn wc_fold(p: vec2f) -> vec2f {
    let m = p - 2.0 * floor(p / 2.0);
    return 1.0 - abs(1.0 - m);
}

// A front spreading over the thresholds of a wash: below -margin at the start, above 1 + margin at the end.
fn wc_front(start: f32, dur: f32, margin: f32) -> f32 {
    var s = clamp((g_progress - start) / dur, 0.0, 1.0);
    s = mix(s, s * s * (3.0 - 2.0 * s), 0.5);
    return s * (1.0 + 2.0 * margin) - margin;
}

// Dried edge of a wash at depth d inside it: a dark line right at the edge, fading inward over w.
fn wc_rim(d: f32, w: f32) -> f32 {
    let r = 1.0 - smoothstep(0.0, w, d);
    return smoothstep(-0.006, 0.004, d) * r * r;
}

fn wc_luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.299, 0.587, 0.114));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    let ratio = globals.size.x / globals.size.y;
    let paper = params.paper;
    let edges = params.edges;
    // The last glaze has covered everything (see d3 below).
    if (progress >= 0.98) { return to_color(uv); }
    let q = vec2f(uv.x * ratio, uv.y);
    let px = vec2f(1.0 / ratio, 1.0);
    let fr = from_color(uv);

    // Paper texture, turned so that the cells of the noise do not line up with the frame.
    let gq = mat2x2f(0.8, 0.6, -0.6, 0.8) * q;
    let grain = 0.55 * wc_noise(gq * 120.0) + 0.45 * wc_noise(gq * 50.0 + 3.1);
    let tooth = 0.03 * (grain - 0.5);
    let w = vec2f(wc_noise(q * 2.5 + 1.3), wc_noise(q * 2.5 + 8.1)) - 0.5;

    var run = vec4f(fr.rgb * fr.a, fr.a);
    for (var i = 0; i < 4; i++) {
        let a = f32(i) * 1.570796 + 0.8;
        let f = from_color(wc_fold(uv + 0.007 * vec2f(cos(a), sin(a)) * px));
        run += vec4f(f.rgb * f.a, f.a);
    }
    var from_run = fr.rgb;
    if (run.a > 0.0) { from_run = run.rgb / run.a; }
    let d0 = wc_front(0.0, 0.4, 0.1) - wc_fbm(q * 2.8 + 0.9 * w + 11.0);
    let lift = smoothstep(-0.03, 0.06, d0);
    let stain = mix(paper.rgb, paper.rgb * from_run, 0.12);
    var c = mix(fr.rgb, mix(from_run, stain, smoothstep(0.0, 0.1, d0)), lift);
    c *= 1.0 - 0.18 * wc_rim(d0, 0.05) * (1.0 - wc_luma(from_run)) * lift;
    c *= (1.0 - 0.06 * lift * (1.0 - smoothstep(0.05, 0.4, d0)) * (1.0 - smoothstep(0.35, 0.6, progress))) * (1.0 - 0.05 * (grain - 0.5) * lift);
    var alpha = mix(fr.a, paper.a, lift);
    // No wash has started yet (see d1 below).
    if (progress <= 0.07) { return vec4f(c, alpha); }

    // Washes carry no detail: they take the colors of the second clip, blurred (broadly for the
    // first one, less for the second) and a little off its shapes, as painted by hand. Their
    // pigment is as dense as the second clip is opaque.
    let hand = uv + 0.012 * w * px;
    var broad = vec4f(0.0);
    var fine = vec4f(0.0);
    for (var i = 0; i < 8; i++) {
        let a = f32(i) * 0.785398 + 0.3;
        let b = to_color(wc_fold(hand + 0.035 * vec2f(cos(a), sin(a)) * px));
        let f = to_color(wc_fold(hand + 0.012 * vec2f(-sin(a), cos(a)) * px));
        broad += vec4f(b.rgb * b.a, b.a);
        fine += vec4f(f.rgb * f.a, f.a);
    }
    let broad_c = broad.rgb / max(broad.a, 1e-3);
    let fine_c = fine.rgb / max(fine.a, 1e-3);
    broad.a /= 8.0;
    fine.a /= 8.0;
    let pool = wc_noise(q * 4.0 + w * 2.0 + 31.0);

    let d1 = wc_front(0.07, 0.43, 0.12) - wc_fbm(q * 3.0 + 1.2 * w + 2.0);
    let cov1 = smoothstep(-0.05, 0.03, d1) * lift;
    let k1 = 0.55 * broad.a;
    var g1 = mix(vec3f(1.0), broad_c, (0.4 + 0.3 * pool) * broad.a);
    let bq = q / 0.3;
    let bc = floor(bq);
    let frill = 0.5 * wc_noise(q * 14.0) + 0.3 * wc_noise(q * 33.0 + 4.0) + 0.2 * wc_noise(q * 80.0 + 9.0);
    var in_bloom = 0.0;
    var bloom_rim = 0.0;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let cell = bc + vec2f(f32(i), f32(j));
            if (wc_hash(cell + vec2f(17.0, 53.0)) < params.blooms) {
                let ctr = cell + 0.3 + 0.4 * vec2f(wc_hash(cell + vec2f(3.0, 71.0)), wc_hash(cell + vec2f(89.0, 9.0)));
                var g = clamp((d1 - 0.08 - 0.2 * wc_hash(cell + vec2f(5.0, 37.0))) / 0.3, 0.0, 1.0);
                g = 1.0 - (1.0 - g) * (1.0 - g) * (1.0 - g);
                // At most 0.32 * 1.55 < 0.5 cells: a bloom never reaches past the cells next to its own.
                let r = g * (0.18 + 0.14 * wc_hash(cell + vec2f(61.0, 7.0))) * (0.45 + 1.1 * frill);
                let d = r - length(bq - ctr);
                let inside = smoothstep(-0.015, 0.015, d);
                in_bloom = max(in_bloom, inside * smoothstep(0.0, 0.25, r));
                bloom_rim = max(bloom_rim, inside * (1.0 - smoothstep(0.0, 0.05, d)) * smoothstep(0.0, 0.1, r));
            }
        }
    }
    g1 = mix(g1, mix(vec3f(1.0), g1, 0.55), in_bloom);
    g1 *= mix(vec3f(1.0), g1 * g1 * 0.9, bloom_rim);
    g1 *= mix(vec3f(1.0), g1, edges * 0.8 * wc_rim(d1, 0.06));

    let t2 = clamp(mix(wc_fbm(q * 3.2 - 1.0 * w + 7.0), mix(1.0, wc_luma(fine_c), fine.a), 0.55) + tooth, 0.0, 1.0);
    let d2 = wc_front(0.25, 0.42, 0.1) - t2;
    let cov2 = smoothstep(-0.006, 0.004, d2) * cov1;
    var g2 = clamp(mix(vec3f(1.0), fine_c, (0.75 + 0.2 * (1.0 - pool)) * fine.a) / mix(vec3f(1.0), broad_c, 0.55 * broad.a), vec3f(0.0), vec3f(1.0));
    g2 *= mix(vec3f(1.0), g2 * g2 * 0.92, edges * wc_rim(d2, 0.07));

    var wash = mix(vec3f(1.0), g1, cov1) * mix(vec3f(1.0), g2, cov2);
    let settle = clamp((grain - 0.5) * 2.0 + 0.5 * (wc_noise(q * 18.0 + 9.0) - 0.5), -0.4, 1.0);
    wash = min(wash * (1.0 - params.granulation * 0.45 * settle * (1.0 - wc_luma(wash))), vec3f(1.0));
    // On paper that is not opaque, the pigment brings its own opacity.
    let a1 = alpha + (1.0 - alpha) * clamp(cov1 * k1 + cov2 * 0.35 * fine.a, 0.0, 1.0);
    c = mix(c * wash, wash, (a1 - alpha) / max(a1, 1e-3));
    alpha = a1;

    let to = to_color(uv);
    let t3 = clamp(mix(wc_fbm(q * 3.6 + 0.8 * w + 19.0), mix(1.0, wc_luma(fine_c), fine.a), 0.45) + tooth, 0.0, 1.0);
    let d3 = wc_front(0.45, 0.53, 0.1) - t3;
    let cov3 = smoothstep(-0.006, 0.004, d3);
    let last = to.rgb * mix(vec3f(1.0), to.rgb * 0.9, edges * 0.7 * wc_rim(d3, 0.05));
    return vec4f(mix(c, last, cov3), mix(alpha, to.a, cov3));
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
