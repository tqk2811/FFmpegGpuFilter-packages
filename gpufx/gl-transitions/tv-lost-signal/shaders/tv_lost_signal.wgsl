// Port of TvLostSignal.glsl from gl-transitions (author: mernking, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvLostSignal.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453);
}

fn transition(uv: vec2f, p: f32) -> vec4f {
    let strength = sin(p * 3.14159265);
    var color = mix(from_color(uv), to_color(uv), p);
    let line_y = floor(uv.y * 120.0);
    let line = step(0.92, hash(vec2f(line_y, p * 20.0)));
    let drift = sin(uv.y * 30.0 + p * 10.0) * 0.02 * strength;
    let line_color = mix(from_color(uv + vec2f(drift, 0.0)), to_color(uv + vec2f(drift, 0.0)), p);
    color = mix(color, line_color, line * strength);
    let scan = sin(uv.y * 900.0) * 0.03;
    return vec4f(color.rgb - scan * strength, color.a);
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
