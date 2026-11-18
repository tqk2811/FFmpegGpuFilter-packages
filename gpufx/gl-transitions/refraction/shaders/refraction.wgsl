// Port of Refraction.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Refraction.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The wavelengths sampled from red to violet.
const TAPS: i32 = 7;

fn surface(q0: vec2f, t: f32) -> f32 {
    let q = q0 + 0.45 * vec2f(sin(1.3 * q0.y + 0.9 * t), sin(1.1 * q0.x - 1.2 * t));
    var h = sin(q.x + 0.6 * t) * sin(1.2 * q.y - 0.8 * t);
    h += 0.5 * sin(dot(q, vec2f(1.6, -1.2)) + 1.4 * t);
    h += 0.3 * sin(dot(q, vec2f(-1.1, 2.9)) - 1.9 * t + 1.7 * sin(0.9 * q.x));
    h += 0.15 * sin(dot(q, vec2f(4.3, 3.1)) + 2.6 * t);
    return h;
}

// A hash without sin, to jitter the wavelengths from pixel to pixel.
fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// Rough spectral response of a wavelength w (0 = red, 1 = violet), in RGB.
fn spectrum(w: f32) -> vec3f {
    let c = vec3f(
        1.0 - smoothstep(0.0, 0.55, w) + 0.35 * smoothstep(0.75, 1.0, w),
        1.0 - abs(2.0 * w - 1.0) * 1.2,
        smoothstep(0.45, 1.0, w));
    return clamp(c, vec3f(0.0), vec3f(1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let h = 1.0 - abs(2.0 * p - 1.0);
    let amount = h * h * (2.0 - h);
    let scale = max(params.scale, 0.01);

    let q = (uv - 0.5) * vec2f(ratio, 1.0) * scale;
    let t = 3.0 * p;
    let e = 0.01;
    let slope = vec2f(
        surface(q + vec2f(e, 0.0), t) - surface(q - vec2f(e, 0.0), t),
        surface(q + vec2f(0.0, e), t) - surface(q - vec2f(0.0, e), t)) / (2.0 * e);
    let offset = slope * params.strength * amount / scale;
    let wave = clamp(0.5 * surface(q, t), -1.0, 1.0);
    let m = smoothstep(-0.015, 0.015, p - 0.5 + 0.1 * wave);

    var color = vec3f(0.0);
    var weights = vec3f(0.0);
    var alpha = 0.0;
    // Jittered wavelengths blend the fringes into a continuous rainbow.
    let jitter = hash12(uv * vec2f(ratio, 1.0) * 1000.0) - 0.5;
    for (var i = 0; i < TAPS; i++) {
        let w = f32(i) / f32(TAPS - 1);
        let wj = (f32(i) + jitter) / f32(TAPS - 1);
        let st = mirror(uv + offset * (1.0 + params.dispersion * (wj - 0.5) * 1.6));
        let c = mix(from_color(st), to_color(st), m);
        let s = spectrum(w);
        color += s * c.rgb * c.a;
        weights += s;
        alpha += c.a;
    }
    alpha /= f32(TAPS);
    color = color / weights / max(alpha, 1e-5);

    let flare = 2.0 * params.brightness * pow(h, 8.0);
    color = color * (1.0 + flare) / (1.0 + flare * color);
    color += 0.1 * flare * dot(color, vec3f(0.3333));
    return vec4f(clamp(color, vec3f(0.0), vec3f(1.0)), alpha);
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
