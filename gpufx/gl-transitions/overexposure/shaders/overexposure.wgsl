// Port of Overexposure.glsl from gl-transitions (author: Ben Zhang, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Overexposure.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let a = from_color(uv);
    let b = to_color(uv);
    let from_m = 1.0 - progress + sin(PI * progress) * params.strength;
    let to_m = progress + sin(PI * progress) * params.strength;
    return vec4f(a.rgb * a.a * from_m + b.rgb * b.a * to_m, mix(a.a, b.a, progress));
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
