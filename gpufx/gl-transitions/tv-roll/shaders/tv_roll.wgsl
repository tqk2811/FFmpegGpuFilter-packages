// Port of TvRoll.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvRoll.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The rolling picture at a vertical position y, in frames of height 1 + bar_height.
fn picture(uv: vec2f, y_in: f32, m: f32) -> vec4f {
    let period = 1.0 + params.bar_height;
    let y = y_in - period * floor(y_in / period);
    if (y > 1.0) { return params.bar_color; }
    let q = vec2f(uv.x, y);
    return mix(from_color(q), to_color(q), m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let rolls = f32(max(params.rolls, 1));
    let period = 1.0 + params.bar_height;
    // Smooth start and stop: the picture locks again after a whole number of frames.
    let s = progress * progress * (3.0 - 2.0 * progress);
    let offset = period * fract(rolls * s);
    let speed = 4.0 * progress * (1.0 - progress);
    let m = smoothstep(0.42, 0.58, progress);
    let p = uv + vec2f(0.004 * speed * sin(uv.y * 9.0 + progress * 30.0), 0.0);
    var c = vec4f(0.0);
    for (var i = 0; i < 5; i++) {
        c += picture(p, p.y + offset - 0.0015 * rolls * speed * f32(i), m);
    }
    c /= 5.0;
    let scan = 0.5 + 0.5 * sin(uv.y * 400.0);
    let flicker = 0.08 * (0.5 + 0.5 * sin(progress * 97.0));
    return vec4f(c.rgb * (1.0 - speed * (0.08 * scan + flicker)), c.a);
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
