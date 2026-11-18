// Port of BokehDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BokehDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const TAPS: i32 = 16;

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

// A hash of an integer cell, stable across precisions.
fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn highlight(c: vec4f, t: f32) -> f32 {
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    // Nothing is brighter than white, so a threshold of 1 makes no highlights.
    if (t >= 1.0) { return 0.0; }
    let h = smoothstep(t, 1.0, lum);
    return h * h * c.a;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let threshold = params.threshold;
    let t = 1.0 - abs(2.0 * progress - 1.0);
    let k = t * t * (3.0 - 2.0 * t);
    let w = smoothstep(0.35, 0.65, progress);
    let r = params.radius * k;
    let boost = 12.0 * params.intensity * k;

    // Fewer than 3 blades: a round aperture.
    var n = 0.0;
    if (params.blades >= 3) { n = f32(params.blades); }
    var sector = 1.0;
    if (n > 0.0) { sector = 2.0 * PI / n; }
    let apothem = cos(0.5 * sector);

    // Per-pixel stratification of the taps over the disc, so its edge stays crisp.
    let cell = floor(uv * vec2f(ratio, 1.0) * 997.0);
    let spin = 2.0 * PI * hash12(cell);
    let jitter = hash12(cell + 17.0);

    // Each clip is only read while it shows.
    let use_from = w < 1.0;
    let use_to = w > 0.0;
    var s0 = vec4f(0.0);
    var s1 = vec4f(0.0);
    var t0 = 0.0;
    var t1 = 0.0;
    var l0 = vec3f(0.0);
    var l1 = vec3f(0.0);
    if (use_from) {
        let c = from_color(uv);
        let h = highlight(c, threshold);
        let wt = 1.0 + boost * h;
        s0 = wt * vec4f(c.rgb * c.a, c.a);
        t0 = wt;
        l0 = h * c.rgb;
    }
    if (use_to) {
        let c = to_color(uv);
        let h = highlight(c, threshold);
        let wt = 1.0 + boost * h;
        s1 = wt * vec4f(c.rgb * c.a, c.a);
        t1 = wt;
        l1 = h * c.rgb;
    }
    for (var i = 0; i < TAPS; i++) {
        let fi = f32(i);
        let a = fi * 2.39996323 + spin;
        var d = sqrt((fi + jitter) / f32(TAPS));
        if (n > 0.0) {
            let s = a - sector * floor(a / sector) - 0.5 * sector;
            d *= apothem / cos(s);
        }
        let st = mirror(uv + r * d * vec2f(cos(a) / ratio, sin(a)));
        if (use_from) {
            let c = from_color(st);
            let h = highlight(c, threshold);
            let wt = 1.0 + boost * h;
            s0 += wt * vec4f(c.rgb * c.a, c.a);
            t0 += wt;
            l0 += h * c.rgb;
        }
        if (use_to) {
            let c = to_color(st);
            let h = highlight(c, threshold);
            let wt = 1.0 + boost * h;
            s1 += wt * vec4f(c.rgb * c.a, c.a);
            t1 += wt;
            l1 += h * c.rgb;
        }
    }
    var b0 = vec4f(0.0);
    var b1 = vec4f(0.0);
    if (use_from) { b0 = s0 / t0; }
    if (use_to) { b1 = s1 / t1; }
    let b = mix(b0, b1, w);
    if (b.a <= 0.0) { return vec4f(0.0); }
    var rgb = b.rgb / b.a;
    // The discs glow: light lifts the color, never the alpha.
    let light = mix(l0, l1, w) * (params.intensity * k * 4.0 / f32(TAPS + 1));
    rgb = 1.0 - (1.0 - clamp(rgb, vec3f(0.0), vec3f(1.0))) * exp(-light);
    return vec4f(rgb, b.a);
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
