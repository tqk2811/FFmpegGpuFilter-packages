// Port of WindowBlinds.glsl from gl-transitions (author: Fabien Benetou, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WindowBlinds.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    var t = progress;
    if (gmod(floor(uv.y * 100.0 * progress), 2.0) == 0.0) { t *= 2.0 - 0.5; }
    return mix(from_color(uv), to_color(uv), mix(t, progress, smoothstep(0.8, 1.0, progress)));
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
