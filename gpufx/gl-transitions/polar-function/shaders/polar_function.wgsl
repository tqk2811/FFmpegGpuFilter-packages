// Port of FlowerWipe.glsl (formerly polar_function.glsl) from gl-transitions
// (author: Fernando Kuteken, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FlowerWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265359;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    // atan2(0, 0) is undefined on some backends: the center pixel takes angle 0.
    let d = uv - vec2f(0.5);
    let angle = select(atan2(d.y, d.x), 0.0, all(d == vec2f(0.0))) - 0.5 * PI;
    let radius = (cos(f32(params.segments) * angle) + 4.0) / 4.0;
    if (length(d) > radius * progress) { return from_color(uv); }
    return to_color(uv);
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
