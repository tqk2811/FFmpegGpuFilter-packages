// Port of HoneyDrip.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HoneyDrip.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AMBER: vec3f = vec3f(1.0, 0.6, 0.18);

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

fn capsule(p: vec2f, y0: f32, y1: f32, r: f32) -> f32 {
    return length(vec2f(p.x, p.y - clamp(p.y, y0, y1))) - r;
}

fn drop_sd(p: vec2f, d: vec3f) -> f32 {
    var q = (p - vec2f(0.0, d.x)) / d.yz;
    // Widest low, narrowing toward the thread.
    q.x /= 1.0 + 0.22 * clamp(q.y, -1.0, 1.0);
    return (length(q) - 1.0) * min(d.y, d.z);
}

// p = (x from the center, depth from the top); b: band bottom, upper thread end, lower thread start,
// thread radius; d: drop center depth and radii; k: blend radius, kc: blend across the snapped thread.
fn honey(p: vec2f, b: vec4f, d: vec3f, k: f32, kc: f32) -> f32 {
    let upper = smin(p.y - b.x, capsule(p, min(b.x + b.w, b.y), b.y, b.w), k);
    let lower = smin(capsule(p, b.z, d.x, b.w), drop_sd(p, d), k);
    return smin(upper, lower, kc);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let gloss = params.gloss;
    let t = progress;
    let big_w = 0.5 * ratio;
    let sn = clamp(params.snap, 0.05, 0.95);
    let u = min(t, sn) / sn;
    let s = u * (2.0 - u);
    let after = max(t - sn, 0.0) / (1.0 - sn);
    let rel = smoothstep(0.0, 1.0, after * 2.5);

    let a_pre = mix(1.06, 0.2, s);
    // The band jerks up when released, wobbles once, then leaves.
    let a = mix(a_pre, -0.12, smoothstep(0.0, 1.0, after * 1.25)) - a_pre * 0.25 * sin(after * 9.0) * exp(-after * 5.0);
    let rx = mix(big_w + 0.15, min(0.5 * big_w, 0.22), s);
    let ry = mix(0.55, min(1.25 * rx + 0.04, 0.3), s);
    let c0 = mix(0.58, 0.95 - ry, s * s);
    // Lands the drop's top just past the bottom edge at the end.
    let fall = (1.06 - c0 + ry) * after * (0.15 + 0.85 * after);
    let c = c0 + fall;
    let rn = mix(big_w, 0.013, pow(s, 0.6)) * (1.0 + 0.6 * rel);
    let k = mix(0.32, 0.09, s * s);
    let ys = mix(a_pre, c0 - ry, 0.45);
    let yu = mix(ys, a, smoothstep(0.0, 1.0, after * 3.0));
    let yl = mix(ys, c0 - 0.8 * ry, smoothstep(0.0, 1.0, after * 1.2)) + fall;
    let kc = k * (1.0 - smoothstep(0.0, 1.0, after * 12.0)) + 1e-4;
    let b = vec4f(a, yu, yl, rn);
    let d = vec3f(c, rx, ry);

    let p = vec2f((uv.x - 0.5) * ratio, 1.0 - uv.y);
    let sd = honey(p, b, d, k, kc);
    let e = vec2f(0.002, 0.0);
    let g = vec2f(
        honey(p + e.xy, b, d, k, kc) - honey(p - e.xy, b, d, k, kc),
        honey(p + e.yx, b, d, k, kc) - honey(p - e.yx, b, d, k, kc)) / (2.0 * e.x);

    // The material keeps its top-to-bottom order: band, a sliver in the thread, the lower picture in the drop.
    let top = max(c - ry, a);
    let v_top = a_pre + 0.1 * (1.0 - a_pre) * clamp((top - a) / 0.1, 0.0, 1.0);
    var v: f32;
    if (p.y < a) { v = p.y + a_pre - a; }
    else if (p.y < top) { v = mix(a_pre, v_top, (p.y - a) / max(top - a, 1e-4)); }
    else { v = mix(v_top, 1.0, clamp((p.y - top) / (c + ry - top), 0.0, 1.0)); }
    // The shape is symmetric and each row is one span, so bisect its half-width.
    var lo = 0.0;
    var hi = big_w;
    for (var i = 0; i < 10; i++) {
        let m = 0.5 * (lo + hi);
        if (honey(vec2f(m, p.y), b, d, k, kc) < 0.0) { lo = m; } else { hi = m; }
    }
    // The band's bottom edge makes the span jump, so ease from the band's width into the thread's.
    let wb = 0.5 * (lo + hi);
    let w = mix(big_w, wb, smoothstep(a, a + 1.5 * k, p.y));
    // Narrow rows show only the middle of the picture, so the drop does not read as a fisheye.
    let sx = clamp(p.x / max(mix(w, max(w, min(rx, big_w)), 0.6), 1e-3), -1.0, 1.0);

    let env = s * (1.0 - smoothstep(0.0, 1.0, after));
    let depth = clamp(-sd / clamp(0.6 * wb, 0.012, 0.18), 0.0, 1.0);
    let h = sqrt(depth * (2.0 - depth));
    // Outward direction, y up; its x part fades on the center line, where the distance field creases.
    let n_out = vec2f(g.x * smoothstep(0.0, 0.3 * w + 1e-3, abs(p.x)), -g.y) / max(length(g), 1e-3);
    let n = normalize(vec3f(n_out * (1.0 - depth) * s * gloss, mix(1.0, max(h, 0.05), s * gloss)));
    let src = vec2f(0.5 + 0.5 * sx, 1.0 - v) - n.xy * 0.03;
    let img0 = from_color(clamp(mix(uv, src, s), vec2f(0.0), vec2f(1.0)));

    let l = normalize(vec3f(-0.4, 0.55, 0.73));
    let dif = 1.0 + 0.45 * (dot(n, l) / l.z - 1.0);
    let rs = max(dot(reflect(-l, n), vec3f(0.0, 0.0, 1.0)), 0.0);
    let bulk = smoothstep(0.02, 0.12, wb) * smoothstep(a, a + k, p.y);
    let thick = depth * bulk;
    // Light focused through the drop gathers inside the rim opposite the light.
    let glow = bulk * smoothstep(0.0, 0.3, depth) * (1.0 - smoothstep(0.3, 1.0, depth)) * max(dot(n_out, -l.xy), 0.0);
    let amt = gloss * s;
    var col = img0.rgb * mix(1.0, dif, amt);
    col *= exp(-amt * (0.08 + thick) * vec3f(0.0, 0.45, 1.2));
    col *= mix(vec3f(1.0), vec3f(0.55, 0.32, 0.1), 0.7 * amt * (1.0 - h) * (1.0 - h));
    col += amt * (1.3 * glow * AMBER + pow(rs, 50.0) + 0.12 * pow(rs, 8.0) * AMBER);
    let img = vec4f(col, img0.a);

    let aa = 0.006;
    let in_honey = clamp(0.5 - sd / aa, 0.0, 1.0);
    let bg0 = to_color(uv);
    let bg = vec4f(bg0.rgb * (1.0 - 0.45 * env * exp(-max(sd, 0.0) * 16.0)), bg0.a);
    return mix(bg, img, in_honey);
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
