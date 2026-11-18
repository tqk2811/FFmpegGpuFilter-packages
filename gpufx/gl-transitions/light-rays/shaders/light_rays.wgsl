// Port of LightRays.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightRays.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 20;
const SHAFTS: f32 = 23.0;
const PI: f32 = 3.141592653589793;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(v.xyx * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn modf_(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

// Smooth noise around the center, wrapping over a full turn (t in 0..1).
fn shaft_noise(t: f32, n: f32, seed: f32) -> f32 {
    let x = t * n;
    let i = floor(x);
    let f = x - i;
    let a = hash12(vec2f(modf_(i, n), seed));
    let b = hash12(vec2f(modf_(i + 1.0, n), seed));
    return mix(a, b, f * f * (3.0 - 2.0 * f));
}

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

fn glow(c: vec4f, knee: f32) -> vec3f {
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    return c.rgb * c.a * smoothstep(knee, knee + 0.2, lum);
}

fn light(st: vec2f, knee: f32, m: f32) -> vec3f {
    if (m <= 0.0) { return glow(from_color(st), knee); }
    if (m >= 1.0) { return glow(to_color(st), knee); }
    return mix(glow(from_color(st), knee), glow(to_color(st), knee), m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    var amount = 1.0 - smoothstep(0.5, 1.0, p);
    if (p < 0.5) { amount = smoothstep(0.0, 0.5, p); }
    let peak = amount * amount * amount;
    let m = smoothstep(0.46, 0.54, p);
    let from_c = from_color(uv);
    let to_c = to_color(uv);
    if (amount <= 0.0) { return select(to_c, from_c, m < 0.5); }

    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let origin = center + vec2f(params.drift * (p - 0.5), 0.0);
    let len = params.reach * amount;
    let knee = mix(params.threshold, 0.75 * params.threshold, peak);
    // A small shift of the taps, under their spacing, blends them into smooth shafts;
    // hashed by integer cell so that every GPU computes the same shift.
    let jitter = hash12(floor(uv * vec2f(ratio, 1.0) * 997.0));

    var rays = vec3f(0.0);
    var total = 0.0;
    for (var i = 0; i < TAPS; i++) {
        let s = (f32(i) + jitter) / f32(TAPS);
        let w = exp(-2.0 * s);
        let hue = mix(vec3f(1.0), params.tint.rgb, smoothstep(0.0, 0.6, s));
        rays += w * hue * light(mirror(mix(uv, origin, s * len)), knee, m);
        total += w;
    }
    let d = (uv - origin) * vec2f(ratio, 1.0);
    // atan is undefined at the center itself.
    var turn = 0.0;
    if (length(d) > 1e-6) { turn = atan2(d.y, d.x) / (2.0 * PI) + 0.5; }
    let shafts = 0.6 * shaft_noise(fract(turn + 0.03 * p), SHAFTS, 1.0) + 0.4 * shaft_noise(fract(turn - 0.05 * p), 2.0 * SHAFTS + 1.0, 7.0);
    // Merged back into a soft glow close to the center, where the shafts would meet in a point.
    rays *= mix(1.0, mix(0.2, 1.6, smoothstep(0.15, 0.85, shafts)), smoothstep(0.0, 0.3, length(d)));
    rays *= params.intensity * amount * (1.0 + 3.0 * peak) / total;
    // Compressed, so that bright areas never flatten into white.
    rays = 0.9 * (1.0 - exp(-rays));

    // The picture stays sharp, with a slight lift at the peak; the rays are screened on top.
    let c = mix(vec4f(from_c.rgb * from_c.a, from_c.a), vec4f(to_c.rgb * to_c.a, to_c.a), m);
    if (c.a <= 0.0) { return vec4f(0.0); }
    let base = min(c.rgb / c.a * (1.0 + 0.2 * peak), vec3f(1.0));
    return vec4f(base + rays - base * rays, c.a);
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
