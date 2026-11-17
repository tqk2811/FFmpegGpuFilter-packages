// Port of LensWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LensWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;
const BEVEL: f32 = 0.07;
// Moment the lens has grown past the farthest corner.
const OPEN: f32 = 0.8;
// Toward the light, from the top left (xy of a unit vector).
const LIGHT: vec2f = vec2f(-0.6, 0.8);

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let aspect = vec2f(ratio, 1.0);
    let sh = clamp(params.shading, 0.0, 1.0);
    let far = max(center, 1.0 - center) * aspect;
    let full = length(far) / (1.0 - BEVEL) + 2.0 * AA;
    let t = clamp(p / OPEN, 0.0, 1.0);
    let radius = full * t * (0.5 + t * (2.0 - 1.5 * t));
    // The magnification relaxes while the lens finishes growing: exactly 0 at the end.
    let k = clamp(params.strength, 0.0, 0.8) * (1.0 - smoothstep(0.35, 1.0, p));
    let d = (uv - center) * aspect;
    let r = length(d);
    var a = vec4f(0.0);
    if (r > radius - 2.0 * AA) {
        a = from_color(uv);
        let sd = length(d + 0.1 * LIGHT * radius) / max(radius, 1e-5);
        let shadow = 0.55 * sh * (1.0 - smoothstep(0.85, 1.35, sd)) * smoothstep(0.0, 0.05, radius);
        a = vec4f(a.rgb * (1.0 - shadow), a.a);
        if (r >= radius) { return a; }
    }
    let s = r / radius;
    let f = 1.0 - k * (1.0 - s * s);
    var n = vec2f(0.0);
    if (r > 0.0) { n = d / r; }
    let ca = n * (0.014 * k * s * s) / aspect;
    let q = center + d * f / aspect;
    // Each channel keeps the alpha of the tap it comes from.
    let cr = to_color(mirror(q + ca));
    let cg = to_color(mirror(q));
    let cb = to_color(mirror(q - ca));
    let alpha = (cr.a + cg.a + cb.a) / 3.0;
    var b = vec4f(vec3f(cr.r * cr.a, cg.g * cg.a, cb.b * cb.a) / max(alpha, 1e-5), alpha);
    let bevel = smoothstep(1.0 - BEVEL, 1.0, s);
    let facing = dot(n, LIGHT);
    let lit = bevel * bevel;
    let shade = vec3f(1.0 - 0.35 * sh * lit * max(-facing, 0.0) - 0.12 * sh * bevel);
    let spec = sh * lit * (0.55 * max(facing, 0.0) + 0.12);
    let g = (d / radius - 0.42 * LIGHT) / vec2f(0.32, 0.2);
    let glint = 0.12 * sh * exp(-dot(g, g)) * (1.0 - smoothstep(0.6, 1.0, p));
    b = vec4f(min(b.rgb * shade + (spec + glint) * b.a, vec3f(1.0)), b.a);
    // Antialiased edge, kept inside the lens so it vanishes with it.
    let cov = clamp((radius - r) / (2.0 * AA), 0.0, 1.0);
    return mix(a, b, cov);
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
