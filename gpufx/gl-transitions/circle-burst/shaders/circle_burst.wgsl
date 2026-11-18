// Port of CircleBurst.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CircleBurst.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;
const SW: f32 = 0.03;
const SO: f32 = 0.32;

fn phase(s: f32, d: f32, progress: f32) -> f32 { return clamp((progress - s) / d, 0.0, 1.0); }

fn radius(t: f32, big_r: f32) -> f32 {
    let u = 1.0 - t;
    return mix(-SW - AA, big_r, mix(t, 1.0 - u * u * u, 0.8));
}

fn mirror(v: vec2f) -> vec2f {
    let a = abs(v);
    return 1.0 - abs(1.0 - (a - 2.0 * floor(a / 2.0)));
}

// A layer of color c and radius r laid over p (premultiplied), with its shadow, at distance x.
fn layer(p_in: vec4f, c: vec4f, r: f32, x: f32) -> vec4f {
    var k = smoothstep(r - AA, r + AA, x);
    let s = SO * c.a * k * (1.0 - smoothstep(0.0, SW, x - r));
    let p = p_in * (1.0 - s) + vec4f(0.0, 0.0, 0.0, s);
    k = c.a * (1.0 - k);
    return p * (1.0 - k) + vec4f(c.rgb, 1.0) * k;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // `center` is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let asp = vec2f(ratio, 1.0);
    let x = length((uv - center) * asp);
    // Past the farthest corner, with room for the shadows.
    let big_r = length(max(center, 1.0 - center) * asp) + SW + AA;
    let k = clamp(params.stagger, 0.0, 1.0);
    let d = 1.0 / (1.0 + 3.0 * k);
    var t = phase(0.0, d, progress);
    let a = from_color(mirror(center + (uv - center) / (1.0 + 0.06 * t * (2.0 - t))));
    var p = vec4f(a.rgb * a.a, a.a);
    p = layer(p, params.color1, radius(t, big_r), x);
    p = layer(p, params.color2, radius(phase(k * d, d, progress), big_r), x);
    let r = radius(phase(2.0 * k * d, d, progress), big_r);
    p = layer(p, params.color3, r, x);
    t = phase(3.0 * k * d, d, progress);
    let h = radius(t, big_r);
    let u = 1.0 - t;
    let b = to_color(mirror(center + (uv - center) / (1.0 + 0.14 * u * u * (1.0 - 2.4 * t))));
    let s = SO * params.color3.a * clamp((r - h) / SW, 0.0, 1.0) * (1.0 - smoothstep(0.0, SW, h - x));
    let q = vec4f(b.rgb * b.a * (1.0 - s), b.a * (1.0 - s) + s);
    p = mix(p, q, 1.0 - smoothstep(h - AA, h + AA, x));
    if (p.a > 0.0) { return vec4f(p.rgb / p.a, p.a); }
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
