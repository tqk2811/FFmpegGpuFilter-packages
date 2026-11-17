// Port of Pinwheel.glsl from gl-transitions (author: Mr Speaker, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Pinwheel.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// GLSL mod: the result has the sign of y.
fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn transition(p: vec2f, progress: f32) -> vec4f {
    let circ_pos = atan2(p.y - 0.5, p.x - 0.5) + progress * params.speed;
    let mod_pos = gmod(circ_pos, 3.1415 / 4.0);
    // Starts just below 0 so the sector edges are not drawn on the first frame.
    let signed = sign(progress * (3.1415 / 4.0 + 0.01) - 0.01 - mod_pos);
    return mix(to_color(p), from_color(p), step(signed, 0.5));
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
