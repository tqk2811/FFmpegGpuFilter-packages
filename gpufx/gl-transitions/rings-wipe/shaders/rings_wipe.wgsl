// Port of RingsWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RingsWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.0015;

// Progress of ring i, from 0 (not started) to 1 (done), each ring lasting d and starting
// k * d after the previous one.
fn ring_progress(i: f32, k: f32, d: f32, t: f32) -> f32 {
    return clamp((t - i * k * d) / d, 0.0, 1.0);
}

// How much ring i, of width w and progress lp, shows the second clip at radius rad and turn a.
fn ring_mask(i: f32, lp: f32, w: f32, rad: f32, a: f32, s: f32) -> f32 {
    let odd = i - 2.0 * floor(i / 2.0) > 0.5;
    if (params.radial != 0u) {
        // The filled part grows across the ring, from its inner edge or from its outer one.
        let e = s / w;
        let f = mix(-e, 1.0 + e, lp);
        let x = clamp((rad - i * w) / w, 0.0, 1.0);
        let dist = select(f - x, f - (1.0 - x), odd) * w;
        return smoothstep(-s, s, dist);
    }
    // A growing arc from the top, clockwise on even rings and counterclockwise on odd ones,
    // soft at both ends, starting empty and ending full.
    let aa = select(a, 1.0 - a, odd);
    let arc = 2.0 * PI * max(rad, s);
    let e = s / arc;
    let lo = mix(e, -e, lp);
    let hi = mix(-e, 1.0 + e, lp);
    let dist = max(min(aa - lo, hi - aa), min(aa - 1.0 - lo, hi - aa + 1.0));
    return smoothstep(-s, s, dist * arc);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = from_color(uv);
    let b = to_color(uv);
    let center = vec2f(params.center.x, 1.0 - params.center.y);

    let n = f32(max(params.count, 1));
    // Measured in square pixels, so the rings are round.
    let p = (uv - center) * vec2f(ratio, 1.0);
    let far = max(center, 1.0 - center) * vec2f(ratio, 1.0);
    let big_r = length(far) + AA;
    let w = big_r / n;
    let rad = length(p);
    var turn = 0.0;
    if (rad > 0.0) { turn = fract(atan2(p.x, p.y) / (2.0 * PI)); }
    let s = max(min(params.smoothness, 0.25 * w), AA);
    let t = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.35);
    let k = clamp(params.stagger, 0.0, 1.0);
    let d = 1.0 / (1.0 + k * (n - 1.0));

    // Blend the two rings on either side of the nearest boundary, so it is antialiased.
    let j = floor(rad / w + 0.5);
    let inner = clamp(j - 1.0, 0.0, n - 1.0);
    let outer = clamp(j, 0.0, n - 1.0);
    let li = ring_progress(inner, k, d, t);
    let lo = ring_progress(outer, k, d, t);
    let m = mix(ring_mask(inner, li, w, rad, turn, s), ring_mask(outer, lo, w, rad, turn, s),
        smoothstep(-AA, AA, rad - j * w));

    // Mixed premultiplied, so transparent clips do not bleed their color.
    var c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);

    // The border between two rings shows from when the inner one starts until the outer one is done.
    let bw = params.border_width;
    if (bw > 0.0 && j >= 1.0 && j <= n - 1.0) {
        let on = min(1.0, 4.0 * li * (1.0 - lo));
        let hw = min(0.5 * bw, 0.5 * w - AA);
        let line = (1.0 - smoothstep(hw - AA, hw + AA, abs(rad - j * w))) * min(1.0, bw / (2.0 * AA));
        let o = params.border_color.a * line * on;
        c = vec4f(params.border_color.rgb * o, o) + c * (1.0 - o);
    }
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
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
