// Port of HeatHaze.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HeatHaze.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

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

// Centered on 0, within [-1.5, 1.5].
fn fbm(v0: vec2f) -> f32 {
    var v = v0;
    var sum = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 4; i++) {
        sum += amp * vnoise(v);
        v = mat2x2f(1.6, 1.2, -1.2, 1.6) * v + 5.3;
        amp *= 0.5;
    }
    return (sum / 0.9375 - 0.5) * 3.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let scale = params.scale;
    let p = progress;
    let amount = sin(PI * p);
    let t = p * params.speed;
    var q = vec2f(uv.x * ratio, uv.y * 2.5) * scale;
    q.y -= t * scale;
    let w = vec2f(fbm(q * 0.35 + vec2f(0.0, t)), fbm(q * 0.35 + vec2f(7.1, -t)));
    q += 1.5 * w;
    var offset = vec2f(fbm(q), 0.5 * fbm(q + vec2f(3.7, 1.9)));
    let ground = mix(1.0, 0.3, uv.y);
    offset *= params.strength * amount * ground * vec2f(1.0 / ratio, 1.0);

    let d = mirror(uv + offset);
    let m = smoothstep(0.3, 0.7, p);
    if (m <= 0.0) { return from_color(d); }
    if (m >= 1.0) { return to_color(d); }
    let a = from_color(d);
    let b = to_color(d);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    let c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
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
