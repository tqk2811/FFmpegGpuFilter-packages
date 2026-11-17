// Port of CrossZoom.glsl from gl-transitions (author: rectalogic, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CrossZoom.glsl
// Based on https://github.com/evanw/glfx.js/blob/master/src/filters/blur/zoomblur.js, with the
// easing of https://github.com/rectalogic/rendermix-basic-effects.
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn linear_ease(begin: f32, change: f32, duration: f32, time: f32) -> f32 {
    return change * time / duration + begin;
}

fn exponential_ease_in_out(begin: f32, change: f32, duration: f32, time_in: f32) -> f32 {
    if (time_in == 0.0) { return begin; }
    if (time_in == duration) { return begin + change; }
    let time = time_in / (duration / 2.0);
    if (time < 1.0) { return change / 2.0 * pow(2.0, 10.0 * (time - 1.0)) + begin; }
    return change / 2.0 * (-pow(2.0, -10.0 * (time - 1.0)) + 2.0) + begin;
}

fn sinusoidal_ease_in_out(begin: f32, change: f32, duration: f32, time: f32) -> f32 {
    return -change / 2.0 * (cos(PI * time / duration) - 1.0) + begin;
}

fn rand(co: vec2f) -> f32 {
    return fract(sin(dot(co, vec2f(12.9898, 78.233))) * 43758.5453);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let center = vec2f(linear_ease(0.25, 0.5, 1.0, progress), 0.5);
    let dissolve = exponential_ease_in_out(0.0, 1.0, 1.0, progress);
    // Mirrored sinusoidal loop: 0 -> strength, then strength -> 0.
    let strength = sinusoidal_ease_in_out(0.0, params.strength, 0.5, progress);

    var color = vec4f(0.0);
    var total = 0.0;
    let to_center = center - uv;
    // Randomizes the lookups to hide the fixed number of samples.
    let offset = rand(uv);
    for (var t = 0.0; t <= 40.0; t += 1.0) {
        let percent = (t + offset) / 40.0;
        let weight = 4.0 * (percent - percent * percent);
        let q = uv + to_center * percent * strength;
        color += mix(from_color(q), to_color(q), dissolve) * weight;
        total += weight;
    }
    return color / total;
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
