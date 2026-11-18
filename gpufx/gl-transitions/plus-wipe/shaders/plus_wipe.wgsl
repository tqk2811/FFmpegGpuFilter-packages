// Port of PlusWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PlusWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn box_dist(p: vec2f, half_size: vec2f) -> f32 {
    let d = abs(p) - half_size;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

fn plus(q: vec2f, t: f32, s: f32, ratio: f32) -> f32 {
    let frame = vec2f(0.5 * ratio, 0.5);
    let k = min(frame.x, frame.y);
    // The arms start equally thick, then widen with the frame proportions.
    let half_width = k * t + (frame - k) * t * t;
    let half_length = 3.0 * max(frame.x, frame.y) * t;
    let d = min(box_dist(q, vec2f(half_length, half_width.y)), box_dist(q, vec2f(half_width.x, half_length)));
    // The soft edge slides from outside to inside the cross.
    return 1.0 - smoothstep(0.0, s, d + s * (1.0 - t));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Measured in square pixels, so the cross is not stretched.
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let s = max(params.smoothness, 0.001);
    var m = plus(q, progress, s, ratio);
    if (params.reverse != 0u) { m = 1.0 - plus(q, 1.0 - progress, s, ratio); }
    return mix(from_color(uv), to_color(uv), m);
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
