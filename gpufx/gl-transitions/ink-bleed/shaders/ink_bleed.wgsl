// Port of InkBleed.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InkBleed.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn vnoise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2f(1.0, 0.0)), f.x),
               mix(hash(i + vec2f(0.0, 1.0)), hash(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn fbm(p_in: vec2f) -> f32 {
    var p = p_in;
    var v = 0.0;
    var a = 0.5;
    for (var i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = mat2x2f(1.6, 1.2, -1.2, 1.6) * p + 7.3;
        a *= 0.5;
    }
    return v / 0.9375;
}

fn fold(p: vec2f) -> vec2f { return 1.0 - abs(1.0 - (p - 2.0 * floor(p / 2.0))); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let seed = params.seed;
    let q = vec2f(uv.x * ratio, uv.y);
    let o = vec2f(seed * 3.1, seed * 1.7);
    let sq = q * 2.2 + o;
    let w1 = vec2f(fbm(sq + vec2f(0.0, 0.6 * p)), fbm(sq + vec2f(5.2, 1.3) - vec2f(0.5 * p, 0.0)));
    let w2 = vec2f(fbm(sq + 3.0 * w1 + vec2f(1.7, 9.2)), fbm(sq + 3.0 * w1 + vec2f(8.3, 2.8)));
    let swirl = fbm(sq * 0.8 + 2.5 * w2) - 0.5;
    let flow = w2 - 0.5;
    let amp = 0.05 + 0.35 * params.tendrils;
    let n = clamp(floor(params.drops + 0.5), 1.0, 8.0);
    let rim_w = 0.1;
    let feather = 0.05;
    // How far the swirls can pull the front back.
    let margin = 1.2 * amp + rim_w + 0.08;
    var f = -1e3;  // > 0 inside the ink
    var fs = -1e3; // the same, only for the drops already fallen, which fades their haze in
    for (var i = 0; i < 8; i++) {
        let fi = f32(i);
        if (fi < n) {
            let hs = vec2f(fi * 7.13 + seed, fi * 3.71 - seed);
            let c = vec2f(mix(0.15, 0.85, hash(hs)) * ratio, mix(0.15, 0.85, hash(hs + 19.7)));
            let start = 0.2 * fi / n;
            let s = clamp((p - start) / (1.0 - start), 0.0, 1.0);
            // Distance to the farthest corner: each bloom alone covers the frame in the end.
            let m = max(c, vec2f(ratio, 1.0) - c);
            let far = length(m) + margin;
            let s3 = s * s * s;
            let r = (far + 0.02) * s * (0.35 + 0.65 * s3 * s3) - 0.02;
            let reach = amp * min(1.0, max(r, 0.0) * 5.0);
            let g = r - length(q - c + 1.3 * reach * flow) + reach * 0.9 * swirl;
            f = max(f, g);
            fs = max(fs, g - 0.15 * (1.0 - min(1.0, s * 12.0)));
        }
    }
    let aa = 0.003;
    let inside = smoothstep(-aa, aa, f);
    let wisp = 1.0 - smoothstep(0.0, 0.08, abs(fbm(sq * 2.0 + 5.0 * w2) - 0.5));
    let soft = smoothstep(-feather, 0.0, fs) * (0.35 + 0.4 * wisp);
    let haze = 0.35 * wisp * (1.0 - smoothstep(0.0, 0.1, -fs));
    let cover = max(inside, max(soft, haze));
    let edge = 1.0 - smoothstep(0.0, rim_w, f);
    var to = to_color(fold(uv - 0.015 * edge * flow / vec2f(ratio, 1.0)));
    to = vec4f(mix(to.rgb, to.rgb * to.rgb * 0.7, params.rim * edge), to.a);
    return mix(from_color(uv), to, cover);
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
