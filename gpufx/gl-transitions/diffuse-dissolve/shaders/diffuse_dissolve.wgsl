// Port of DiffuseDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DiffuseDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;

// A hash of an integer cell, stable across precisions.
fn hash42(p: vec2f) -> vec4f {
    var p4 = fract(vec4f(p.x, p.y, p.x, p.y) * vec4f(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = 1.0 - abs(2.0 * progress - 1.0);
    let amount = a * a * (3.0 - 2.0 * a);
    let cell = floor(uv * vec2f(ratio, 1.0) / max(params.grain_size, 1e-4));
    let h = hash42(cell);
    let angle = 2.0 * PI * (h.x + params.shimmer * (2.0 * h.w - 1.0) * progress);
    let dist = params.radius * amount * 0.5 * (h.y + h.z);
    let offset = dist * vec2f(cos(angle) / ratio, sin(angle));
    let suv = mirror(uv + offset);
    // Each grain switches at its own moment around the peak (hashed off the cell corners,
    // independently of the scatter).
    let when = 0.3 + 0.4 * hash42(cell + vec2f(0.5, 0.25)).x;
    let m = smoothstep(when - 0.1, when + 0.1, progress);
    // Each clip is only read while it shows.
    if (m <= 0.0) { return from_color(suv); }
    if (m >= 1.0) { return to_color(suv); }
    return mix(from_color(suv), to_color(suv), m);
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
