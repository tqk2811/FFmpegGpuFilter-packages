// Port of TangentMotionBlur.glsl from gl-transitions (author: chenkai, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TangentMotionBlur.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn rand(co: vec2f) -> f32 {
    return fract(sin(dot(co, vec2f(12.9898, 78.233))) * 43758.5453);
}

// Premultiplied sums, so transparent samples do not darken the blur.
fn motion_blur(st: vec2f, speed: vec2f, incoming: bool) -> vec4f {
    var color = vec3f(0.0);
    var alpha = 0.0;
    var total = 0.0;
    let offset = rand(st);
    for (var t = 0; t <= 20; t++) {
        let percent = (f32(t) + offset) / 20.0;
        let weight = 4.0 * (percent - percent * percent);
        let uv = fract(st + speed * percent);
        let c = select(from_color(uv), to_color(uv), incoming);
        color += c.rgb * c.a * weight;
        alpha += c.a * weight;
        total += weight;
    }
    return vec4f(color / max(alpha, 1e-5), alpha / total);
}

fn ba(a1: f32, a2: f32) -> f32 { return 1.0 - 3.0 * a2 + 3.0 * a1; }
fn bb(a1: f32, a2: f32) -> f32 { return 3.0 * a2 - 6.0 * a1; }
fn bc(a1: f32) -> f32 { return 3.0 * a1; }
fn slope(t: f32, a1: f32, a2: f32) -> f32 { return 3.0 * ba(a1, a2) * t * t + 2.0 * bb(a1, a2) * t + bc(a1); }
fn bezier(t: f32, a1: f32, a2: f32) -> f32 { return ((ba(a1, a2) * t + bb(a1, a2)) * t + bc(a1)) * t; }

fn t_for_x(x: f32, x1: f32, x2: f32) -> f32 {
    var t = x;
    for (var i = 0; i < 4; i++) {
        let s = slope(t, x1, x2);
        if (s == 0.0) { return t; }
        t -= (bezier(t, x1, x2) - x) / s;
    }
    return t;
}

fn key_spline(x: f32, x1: f32, y1: f32, x2: f32, y2: f32) -> f32 {
    return bezier(t_for_x(x, x1, x2), y1, y2);
}

fn normpdf(x: f32) -> f32 {
    let d = x - 0.5;
    return exp(-20.0 * d * d);
}

fn rotate_uv(uv: vec2f, angle: f32, anchor: vec2f) -> vec2f {
    let s = sin(angle);
    let c = cos(angle);
    return mat2x2f(c, -s, s, c) * (uv - anchor) + anchor;
}

fn swing(uv: vec2f, e: f32, ratio: f32) -> vec2f {
    let rotation = 3.14159;
    let r = select(-rotation + rotation * e, rotation * e, e <= 0.5);
    var p = uv;
    p.y *= 1.0 / ratio;
    p = rotate_uv(p, r, vec2f(1.0, 0.0));
    p.y *= ratio;
    return p;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let e = key_spline(progress, 0.68, 0.01, 0.17, 0.98);
    let blur = max(normpdf(e) - exp(-5.0), 0.0) / (1.0 - exp(-5.0));
    let current = swing(uv, e, ratio);
    // The rotation one frame later at 30 fps; the half switch stays on the same side.
    let dt = 0.0167 * 2.0;
    let rotation = 3.14159;
    let r = select(-rotation + rotation * (e + dt), rotation * (e + dt), e <= 0.5);
    var next = uv;
    next.y *= 1.0 / ratio;
    next = rotate_uv(next, r, vec2f(1.0, 0.0));
    next.y *= ratio;
    let speed = (next - current) / dt * blur * 0.5;
    return motion_blur(current, speed, e > 0.5);
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
