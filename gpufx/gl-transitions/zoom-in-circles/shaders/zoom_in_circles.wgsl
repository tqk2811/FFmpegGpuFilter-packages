// Port of ZoomInCircles.glsl from gl-transitions (author: dycm8009, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ZoomInCircles.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn zoom(uv: vec2f, amount: f32) -> vec2f { return 0.5 + (uv - 0.5) * amount; }

fn transition(uv_in: vec2f, progress: f32) -> vec4f {
    var uv = uv_in;
    let ratio = globals.size.x / globals.size.y;
    let r = length(2.0 * ((uv - 0.5) * vec2f(1.0, 1.0 / ratio)));
    let pro = progress / 0.8;
    var z = pro * 0.2;
    var t = 0.0;
    if (pro > 1.0) {
        z = 0.2 + (pro - 1.0) * 5.0;
        t = clamp((progress - 0.8) / 0.07, 0.0, 1.0);
    }
    if (r < 0.5 + z) {
        // The inner disc keeps its size.
    } else if (r < 0.8 + z * 1.5) {
        uv = zoom(uv, 1.0 - 0.15 * pro);
        t = t * 0.5;
    } else if (r < 1.2 + z * 2.5) {
        uv = zoom(uv, 1.0 - 0.2 * pro);
        t = t * 0.2;
    } else {
        uv = zoom(uv, 1.0 - 0.25 * pro);
    }
    return mix(from_color(uv), to_color(uv), t);
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
