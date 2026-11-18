// Port of StickySplit.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StickySplit.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.002;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn mirror1(v: f32) -> f32 { return 1.0 - abs(1.0 - abs(v)); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let q = vec2f(uv.x * ratio, uv.y);
    let x0 = 0.5 * ratio + 0.012 * sin(q.y * 7.0 + 1.0) + 0.006 * sin(q.y * 19.0 + 2.0);
    // Slow while the goo holds, then the halves let go and slide off.
    let dd = 0.5 * ratio + 0.06;
    let p = progress;
    let d = dd * p * (0.45 + 0.55 * p * p);
    let gg = d / dd;
    let hh = min(q.x - x0 + d, x0 + d - q.x);
    let on = smoothstep(0.0, 0.03, gg);
    if (hh < 0.0) {
        let h = select(q - vec2f(d, 0.0), q + vec2f(d, 0.0), q.x < x0);
        let c = from_color(vec2f(h.x / ratio, h.y));
        return vec4f(c.rgb * (1.0 - 0.2 * params.gloss * on * (1.0 - smoothstep(0.0, 0.015, -hh))), c.a);
    }
    let s = clamp((q.x - x0) / max(d, 1e-5), -1.0, 1.0);
    let n = max(f32(params.strings), 1.0);
    let fade = 1.0 - smoothstep(0.85, 0.98, p);
    var best = -1.0;
    var best_n = 0.0;
    var best_w = 1.0;
    var best_off = 0.0;
    var cov = 0.0;
    var shade = 0.0;
    for (var i = 0; i < 32; i++) {
        let fi = f32(i);
        if (fi >= n) { break; }
        let o = vec2f(fi, 7.3 * params.seed);
        let h1 = hash(o + 1.7);
        let h2 = hash(o + 2.9);
        let h3 = hash(o + 4.1);
        let h4 = hash(o + 5.3);
        let h5 = hash(o + 6.7);
        let h6 = hash(o + 8.3);
        let y_l = (fi + 0.5 + 0.9 * (h1 - 0.5)) / n;
        let st = smoothstep(0.12 + 0.1 * h3, 0.4 + 0.12 * h5, p);
        let y_r = y_l + (h2 - 0.5) * 3.5 / n * st;
        let hang = params.sag * (0.1 + 0.9 * h3 * h3) * 0.45 * gg;
        // Thick strings hold on longest.
        let ts = 0.45 + 0.2 * h4 + 0.2 * h6;
        let k = smoothstep(ts, ts + 0.05, p);
        let sb = 0.7 * (h5 - 0.5);
        let side = select(1.0, -1.0, s < sb);
        let a = (1.0 - side * s) * d;
        let a_tip = mix((1.0 - side * sb) * d, 0.035 + 0.03 * h1, k);
        let line_y = mix(y_l, y_r, 0.5 * s + 0.5);
        let yc = line_y - hang * (1.0 - s * s) * (1.0 - k) - k * params.sag * 1.5 * a * a;
        let slope = (0.5 * (y_r - y_l) + 2.0 * hang * s * (1.0 - k)) / max(d, 1e-4) + 3.0 * k * params.sag * a * side;
        let dist = abs(q.y - yc) / sqrt(1.0 + slope * slope);
        var hw = mix(0.9 / n, mix(0.008, 0.03, h6 * h6) * 0.35 / (0.35 + d), st);
        hw *= mix(1.0, 0.6 + 0.4 * s * s, st) * (0.8 + 0.4 * sin(s * (4.0 + 5.0 * h2) + 6.28 * h4));
        hw *= 1.0 - 0.7 * smoothstep(ts - 0.08, ts, p) * exp(-(s - sb) * (s - sb) * 30.0);
        hw += 0.6 / n * exp(-(1.0 - abs(s)) * d / 0.025);
        hw *= fade * mix(1.0, smoothstep(0.0, 0.025, a_tip - a), k);
        let m = hw - dist;
        if (m > best) {
            best = m;
            best_n = q.y - yc;
            best_w = hw;
            best_off = yc - line_y;
        }
        let fat = clamp(hw / AA, 0.0, 1.0);
        cov = max(cov, smoothstep(-AA, AA, m) * fat);
        shade = max(shade, smoothstep(-0.008, 0.004, hw - abs(q.y + 0.01 - yc)) * fat);
    }
    var c = from_color(vec2f(x0 / ratio, mirror1(q.y - best_off)));
    // Flat inside the web, round near its edges and across thin strings.
    let body = clamp(best / max(min(best_w, 0.01), 1e-5), 0.0, 1.0);
    let nn = sign(best_n) * (1.0 - body);
    let g = params.gloss * on;
    c = vec4f(c.rgb * (1.0 - g * 0.35 * (1.0 - sqrt(1.0 - nn * nn))), c.a);
    c = vec4f(c.rgb + g * 0.45 * exp(-(nn - 0.5) * (nn - 0.5) * 40.0) * c.a, c.a);
    var inc = to_color(uv);
    inc = vec4f(inc.rgb * (1.0 - 0.4 * g * shade - 0.25 * g * fade * exp(-hh / 0.012)), inc.a);
    let w = mix(1.0, cov, smoothstep(0.0, 2.0 * AA, 2.0 * d));
    return mix(inc, c, w);
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
