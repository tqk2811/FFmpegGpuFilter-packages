// Port of SpotlightWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpotlightWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Height of the oval over its width: a cone of light hitting a stage seen at an angle.
const FLAT_Y: f32 = 0.72;
// Distance to the spotlight's center, in oval radii, inside which the second clip is fully lit.
const LIT: f32 = 0.74;

// A point of the curved path the spotlight searches along, from the lower left to its resting point.
fn path(t: f32, c: vec2f) -> vec2f {
    let a = vec2f(0.08, 0.3);
    let b = vec2f(0.35, 1.15);
    let d = vec2f(1.05, 0.95);
    let s = 1.0 - t;
    return s * s * s * a + 3.0 * s * s * t * b + 3.0 * s * t * t * d + t * t * t * c;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let asp = vec2f(ratio, 1.0);
    let p = progress;
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    var t = clamp(p / 0.5, 0.0, 1.0);
    t = t * t * (3.0 - 2.0 * t);
    let c = path(t, center);
    let far = max(center, 1.0 - center) * asp;
    let full = length(vec2f(far.x, far.y / FLAT_Y)) / LIT;
    let g = smoothstep(0.44, 1.0, p);
    let radius = mix(0.5 * params.size, full, g * (0.3 + 0.7 * g));
    let q = (uv - c) * asp;
    let r = length(vec2f(q.x, q.y / FLAT_Y)) / radius;
    let core = 1.0 - smoothstep(0.72, 1.08, r);
    let ring = (r - 0.9) / 0.09;
    let spot = max(core * (1.0 - 0.1 * r * r), 0.12 * (1.0 - smoothstep(0.9, 2.4, r))) + 0.16 * exp(-ring * ring);
    let s = params.darkness * smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.72, 1.0, p));
    let light = 1.0 - s + s * spot * params.warmth.rgb;
    let lit = smoothstep(0.42, 0.58, p) * (1.0 - smoothstep(LIT, 1.0, r));
    let col = mix(from_color(uv), to_color(uv), lit);
    return vec4f(col.rgb * light, col.a);
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
