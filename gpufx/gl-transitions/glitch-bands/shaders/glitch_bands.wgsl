// Port of GlitchBands.glsl from gl-transitions (author: Yoni Maltsman, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchBands.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let f0 = from_color(uv);
    let to = to_color(uv);
    let sphere = dot(f0.rgb, f0.rgb) - 1.0;
    let spiral_x = cos(sphere - uv.x / (progress + 0.01));
    let spiral_y = sin(sphere - uv.y / (progress + 0.01));
    let st = vec2f(fract(params.ampx * uv.x * spiral_x), fract(params.ampy * uv.y * spiral_y));
    let diff = uv - st;
    return mix(from_color(uv + progress * diff), to, progress);
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
