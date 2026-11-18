// Port of BloomDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BloomDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Pairs of opposite taps: 20 reads per pixel.
const PAIRS: i32 = 10;
const GOLDEN_ANGLE: f32 = 2.399963;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

// The picture on screen at a point, premultiplied: one clip, or both during the short switch.
fn image(st: vec2f, m: f32) -> vec4f {
    let a = from_color(st);
    let b = to_color(st);
    return mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
}

fn glow(c: vec4f, knee: f32) -> vec3f {
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    return c.rgb * smoothstep(knee, knee + max(0.3 * (1.0 - knee), 1e-3), lum);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let amount = 4.0 * p * (1.0 - p);
    let peak = amount * amount;
    let flood = peak * peak * peak;
    let m = smoothstep(0.44, 0.56, p);
    var c = image(uv, m);
    if (c.a <= 0.0) { return vec4f(0.0); }
    c = vec4f(c.rgb / c.a, c.a);
    let knee = params.threshold * (1.0 - 0.3 * peak) * (1.0 - flood);
    let radius = params.spread * amount;
    // A rotation and a radial shift of the spiral for each pixel blend the taps into a smooth glow.
    let cell = floor(uv * vec2f(ratio, 1.0) * 997.0);
    let spin = 6.2831853 * hash12(cell);
    let shift = hash12(cell + 71.0);
    // A golden-angle spiral, denser toward the center; each tap is read with its opposite.
    var bloom = vec3f(0.0);
    var soft = vec4f(0.0);
    var total = 0.0;
    for (var i = 0; i < PAIRS; i++) {
        let s = (f32(i) + shift) / f32(PAIRS);
        let r = s * s;
        let a = f32(i) * GOLDEN_ANGLE + spin;
        let offset = radius * r * vec2f(cos(a) / ratio, sin(a));
        let i0 = image(mirror(uv + offset), m);
        let i1 = image(mirror(uv - offset), m);
        let l = glow(i0, knee) + glow(i1, knee);
        // The sparse outer taps weigh less, so the tail of the glow stays smooth.
        let w = 1.0 - 0.75 * s;
        bloom += w * mix(vec3f(1.0), params.tint.rgb, smoothstep(0.0, 0.5, r)) * l;
        total += w;
        let sw = (1.0 - s) * (1.0 - s);
        soft += sw * (i0 + i1);
    }
    bloom /= 2.0 * total;
    // At the peak the light softens the picture itself, which hides the switch.
    var blurred = c.rgb;
    if (soft.a > 0.0) { blurred = soft.rgb / soft.a; }
    var base = mix(c.rgb, blurred, 0.7 * flood);
    bloom *= params.intensity * peak * (1.0 + 2.0 * flood);
    // Compressed, so that the glow floods the frame without flattening into white.
    bloom = 0.92 * (1.0 - exp(-bloom));
    // The glow is a light screened over the picture: it adds nothing to its alpha.
    base = min(base * (1.0 + 0.25 * peak), vec3f(1.0));
    return vec4f(base + bloom - base * bloom, c.a);
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
