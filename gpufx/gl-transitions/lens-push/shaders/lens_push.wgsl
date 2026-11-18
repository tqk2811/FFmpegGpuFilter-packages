// Port of LensPush.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LensPush.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SAMPLES: i32 = 24;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn strip(q: vec2f, d: vec2f) -> vec4f {
    if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) { return from_color(q); }
    return to_color(mirror(q + d));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Snap to the nearest of the 8 directions: drop a component under tan(22.5deg) of the other.
    let ad = abs(params.direction);
    var d = sign(params.direction) * step(vec2f(0.4142 * max(ad.x, ad.y)), ad);
    if (dot(d, d) == 0.0) { d = vec2f(-1.0, 0.0); }
    let p = progress;
    // Smooth start and landing; the motion blur follows the speed (1.875 at the peak).
    let pos = p * p * p * (p * (p * 6.0 - 15.0) + 10.0);
    let speed = 30.0 * p * p * (1.0 - p) * (1.0 - p) / 1.875;
    let len = clamp(params.blur, 0.0, 1.0) * 0.25 * speed;
    let h = 1.0 - abs(2.0 * p - 1.0);
    let hs = h * h * (3.0 - 2.0 * h);
    let k = clamp(params.strength, 0.0, 1.0) * 0.75 * hs;
    let ca = clamp(params.fringe, 0.0, 1.0) * 0.06 * hs;
    // Round barrel lens that keeps the corners in place: 1.0 at the corners.
    let aspect = vec2f(ratio, 1.0);
    let r = length((uv - 0.5) * aspect) / length(0.5 * aspect);
    let r2 = r * r;
    // Each tap is both a step of the motion blur and a wavelength, so colors split toward the edges.
    let jitter = hash(uv * aspect * 731.0);
    var col = vec3f(0.0);
    var wsum = vec3f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        let t = (f32(i) + 0.5) / f32(SAMPLES);
        let w = vec3f(t, 1.0 - abs(2.0 * t - 1.0), 1.0 - t);
        let q = 0.5 + (uv - 0.5) * (1.0 - k + k * r2) * (1.0 - ca * (1.0 - t) * r2);
        let b = fract((f32(i) * 7.0 + jitter) / f32(SAMPLES)) - 0.5;
        let c = strip(q - d * clamp(pos + len * b, 0.0, 1.0), d);
        col += w * c.rgb * c.a;
        wsum += w * c.a;
        alpha += c.a;
    }
    col /= max(wsum, vec3f(1e-5));
    col *= 1.0 - 0.45 * k * r2;
    return vec4f(col, alpha / f32(SAMPLES));
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
