// Port of FilmDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// sRGB to linear light (the exact piecewise curve).
fn to_linear(c: vec3f) -> vec3f {
    let lo = c / 12.92;
    let hi = pow((c + 0.055) / 1.055, vec3f(2.4));
    return select(lo, hi, c > vec3f(0.04045));
}

fn to_srgb(c: vec3f) -> vec3f {
    let lo = c * 12.92;
    let hi = 1.055 * pow(c, vec3f(1.0 / 2.4)) - 0.055;
    return select(lo, hi, c > vec3f(0.0031308));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let a = from_color(uv);
    let b = to_color(uv);
    let t = mix(progress, smoothstep(0.0, 1.0, progress), params.smoothness);
    let la = to_linear(clamp(a.rgb, vec3f(0.0), vec3f(1.0))) * a.a;
    let lb = to_linear(clamp(b.rgb, vec3f(0.0), vec3f(1.0))) * b.a;
    let base = mix(la, lb, t);
    let alpha = mix(a.a, b.a, t);
    // Each clip stays brighter for longer, as in an additive dissolve, rolled off toward full
    // exposure so bright areas glow instead of clipping.
    let extra = params.overlap * min(t, 1.0 - t);
    let excess = extra * (la + lb);
    let room = max(vec3f(alpha) - base, vec3f(1e-5));
    let color = base + room * (1.0 - exp(-excess / room));
    if (alpha <= 0.0) { return vec4f(0.0); }
    return vec4f(to_srgb(clamp(color / alpha, vec3f(0.0), vec3f(1.0))), alpha);
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
