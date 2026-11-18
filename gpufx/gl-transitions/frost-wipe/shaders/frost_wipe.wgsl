// Port of FrostWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FrostWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 12;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(v.xyx * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn vnoise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
        mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn ridged(v0: vec2f) -> f32 {
    var v = v0;
    var sum = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 4; i++) {
        let n = 1.0 - abs(2.0 * vnoise(v) - 1.0);
        sum += amp * n * n;
        v = mat2x2f(1.6, 1.2, -1.2, 1.6) * v + 4.7;
        amp *= 0.5;
    }
    return sum / 0.9375;
}

// Crystal grains, cells of size 1: x is how far from the boundary between two grains (0 on it,
// where the crystals start), y a random number for the grain, zw the position relative to the
// grain's seed.
fn grains(v: vec2f) -> vec4f {
    let i = floor(v);
    let f = fract(v);
    var d1 = 8.0;
    var d2 = 8.0;
    var seed = vec3f(0.0);
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let c = vec2f(f32(x), f32(y));
            let o = c + vec2f(hash12(i + c), hash12(i + c + 17.3)) - f;
            let d = dot(o, o);
            if (d < d1) {
                d2 = d1;
                d1 = d;
                seed = vec3f(hash12(i + c + 41.9), -o);
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    return vec4f(sqrt(d2) - sqrt(d1), seed);
}

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

fn image(uv: vec2f, m: f32) -> vec4f {
    if (m <= 0.0) { return from_color(uv); }
    if (m >= 1.0) { return to_color(uv); }
    return mix(from_color(uv), to_color(uv), m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let color = params.color;
    let p = progress;
    // 0 at both ends, 1 while the frost covers the whole frame (from 0.425 to 0.575).
    let h = 1.0 - abs(2.0 * p - 1.0);
    var a = clamp(h / 0.85, 0.0, 1.0);
    a = a * (1.6 - 0.6 * a);
    let m = smoothstep(0.47, 0.53, p);
    if (a <= 0.0) { return image(uv, m); }

    let q = uv * vec2f(ratio, 1.0);
    let d_edge = min(uv, 1.0 - uv) * vec2f(ratio, 1.0);
    var depth = min(d_edge.x, d_edge.y) / (0.5 * min(ratio, 1.0));
    depth = 1.0 - (1.0 - depth) * (1.0 - depth); // the covered area grows evenly

    // The front moves from the edges past the deepest point; the crystals only hold it back.
    let reach = 0.2 + 0.6 * clamp(params.spread, 0.0, 1.0);
    let front = mix(-0.1, 1.0 + reach + 0.2, a);
    if (depth > front + 0.08) { return image(uv, m); }

    let gv = q * params.scale;
    let gr = grains(gv + 0.35 * vec2f(vnoise(gv * 1.7), vnoise(gv * 1.7 + 23.1)));
    // The needles' direction, any angle (a rational point on the unit circle).
    let u = 2.0 * gr.y - 1.0;
    let dir = vec2f(1.0 - u * u, 2.0 * u) / (1.0 + u * u);
    let t = dot(gr.zw, dir) * 7.0;
    let needle = 1.0 - abs(2.0 * fract(t) - 1.0);
    let nh = fract(gr.y + 0.618034 * floor(t));
    let len = mix(0.15, 0.6, nh);
    let r = ridged(gv * 1.3);
    let rf = ridged(gv * 4.0 + 11.0);
    let grow = min(gr.x * 3.5, gr.x / len * 0.5 + (1.0 - needle) * 1.2 + 0.2 * fract(nh * 13.7));
    let field = depth + reach * (0.8 * min(grow, 1.0) + 0.2 * (1.0 - r)) + 0.1 * (1.0 - rf);
    let under_frost = front - field; // > 0 under the frost
    let f = smoothstep(0.0, 0.03, under_frost);
    let haze = 0.4 * smoothstep(0.9, 1.0, rf) * smoothstep(-0.08, 0.0, under_frost);
    let frost = max(f, haze);
    if (frost <= 0.0) { return image(uv, m); }

    let thick = smoothstep(0.0, 0.5, under_frost);
    let full = smoothstep(0.75, 0.95, h); // the frost turns opaque to hide the switch

    let radius = (0.004 + 0.03 * params.blur) * frost * (0.5 + 0.5 * thick);
    let rot = 6.2831853 * hash12(floor(q * 90.0));
    var rgb = vec3f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < TAPS; i++) {
        let k = (f32(i) + 0.5) / f32(TAPS);
        let th = rot + f32(i) * 2.3999632;
        let off = sqrt(k) * vec2f(cos(th), sin(th)) * radius;
        let c = image(mirror(uv + off / vec2f(ratio, 1.0)), m);
        rgb += c.rgb * c.a;
        alpha += c.a;
    }
    alpha /= f32(TAPS);
    if (alpha > 0.0) { rgb = rgb / (alpha * f32(TAPS)); } else { rgb = vec3f(0.0); }

    let stem = 1.0 - smoothstep(0.0, 0.03, gr.x);
    let needles = smoothstep(0.7, 1.0, needle) * (1.0 - smoothstep(0.0, len, gr.x));
    let glint = 0.4 + 0.6 * rf;
    let veins = clamp(glint * max(0.35 * stem, 0.55 * needles) + 0.3 * smoothstep(0.6, 0.95, r), 0.0, 1.0);
    let rim = smoothstep(0.0, 0.02, under_frost) * (1.0 - smoothstep(0.02, 0.07, under_frost));
    let ice = clamp(color.rgb * (0.82 + 0.25 * veins), vec3f(0.0), vec3f(1.0));
    var cover = frost * (0.35 + 0.3 * thick + 0.25 * veins);
    cover = clamp(mix(cover, frost, full), 0.0, 1.0);
    let under = vec4f(rgb * mix(vec3f(1.0), color.rgb, 0.5 * frost), alpha);
    // The frost color mixes as straight RGBA, like every fill color.
    var res = mix(under, vec4f(ice, color.a), cover);

    let sq = q * 36.0;
    let cell = floor(sq);
    let d = abs(sq - cell - 0.25 - 0.5 * vec2f(hash12(cell + 1.3), hash12(cell + 5.9)));
    let star = max(0.0, 1.0 - 9.0 * length(d)) + max(0.0, 1.0 - 4.0 * (d.x + d.y) - 30.0 * min(d.x, d.y));
    let tw = 0.5 + 0.5 * sin(6.2831853 * (hash12(cell + 9.1) + 2.0 * p));
    let sparkle = step(0.82, hash12(cell + 3.7)) * min(star, 1.0) * tw * f * (0.4 + 0.6 * veins);
    let light = clamp(0.4 * rim + 0.8 * sparkle, 0.0, 1.0);
    res = mix(res, vec4f(mix(color.rgb, vec3f(1.0), 0.6), color.a), light);
    return clamp(res, vec4f(0.0), vec4f(1.0));
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
