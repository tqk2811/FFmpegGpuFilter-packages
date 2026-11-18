// Port of OutlineFill.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/OutlineFill.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 30;

fn luma(c: vec4f) -> f32 {
    return dot(c.rgb, vec3f(0.299, 0.587, 0.114)) * c.a + 0.3 * (1.0 - c.a);
}

fn hash(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.xyx) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn vnoise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2f(1.0, 0.0)), f.x), mix(hash(i + vec2f(0.0, 1.0)), hash(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var b = to_color(uv);
    let l0 = luma(b);
    let th = mix(0.02, 0.24, clamp(params.threshold, 0.0, 1.0));
    let e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
    let front = mix(-0.1, 1.12, e);
    var m = smoothstep(0.88, 1.12, front);
    var wet = smoothstep(0.88, 1.12, front - 0.12);
    var diff = 0.0;
    let spin = 3.1416 * vnoise(uv * vec2f(ratio, 1.0) * 6.0);
    var dir = vec2f(cos(spin), sin(spin));
    // Golden angle rotation, so the taps make a spiral without per-tap trig.
    let turn = mat2x2f(-0.73736, 0.67549, -0.67549, -0.73736);
    for (var i = 0; i < TAPS; i++) {
        let f = (f32(i) + 0.5) / f32(TAPS);
        let r = 0.01 + 0.99 * f * sqrt(f);
        let l = luma(to_color(mirror(uv + params.reach * r * vec2f(dir.x / ratio, dir.y))));
        dir = turn * dir;
        diff = mix(diff, abs(l - l0), 0.2);
        let hit = smoothstep(th * 0.3, th, diff);
        m = max(m, hit * smoothstep(r - 0.1, r + 0.1, front));
        wet = max(wet, hit * smoothstep(r - 0.1, r + 0.1, front - 0.12));
    }
    let rim = max(m - wet, 0.0) * (1.0 - smoothstep(0.8, 1.0, progress));
    b = vec4f(b.rgb * (1.0 - 0.25 * rim), b.a);
    return mix(from_color(uv), b, m);
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
