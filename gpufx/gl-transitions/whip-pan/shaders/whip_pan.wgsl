// Port of WhipPan.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WhipPan.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SAMPLES: i32 = 24;

// The panned strip: the first clip, then the second behind it.
fn strip(q: vec2f, d: vec2f) -> vec4f {
    if (dot(q - 0.5, -d) < 0.5 * dot(d, d)) { return from_color(clamp(q, vec2f(0.0), vec2f(1.0))); }
    return to_color(clamp(q + d, vec2f(0.0), vec2f(1.0)));
}

fn rand(co: vec2f) -> f32 {
    return fract(sin(dot(co, vec2f(12.9898, 78.233))) * 43758.5453);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let d = sign(params.direction);
    let p = progress;
    let h = 1.0 - abs(2.0 * p - 1.0);
    // Mostly cubic, with a bit of linear so that it starts moving at once.
    let e = 0.5 * h * (0.1 + 0.9 * h * h);
    let pos = select(1.0 - e, e, p < 0.5);
    let len = params.blur * h * (0.1 + 2.7 * h * h) / 2.8;
    let q = uv - d * pos;
    // Average along the motion, jittered to hide the sample steps.
    let jitter = rand(uv);
    var color = vec3f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        let t = (f32(i) + jitter) / f32(SAMPLES) - 0.5;
        let c = strip(q + d * t * len, d);
        color += c.rgb * c.a;
        alpha += c.a;
    }
    return vec4f(color / max(alpha, 1e-5), alpha / f32(SAMPLES));
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
