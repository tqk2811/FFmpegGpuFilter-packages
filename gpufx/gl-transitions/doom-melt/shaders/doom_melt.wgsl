// Port of DoomMelt.glsl from gl-transitions (author: Zeh Fernando, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DoomMelt.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// GLSL mod: the result has the sign of y.
fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn bars() -> i32 { return max(params.bars, 2); }

fn rand(num: i32) -> f32 {
    let n = f32(num);
    return fract(gmod(n * 67123.313, 12.0) * sin(n * 10.3) * cos(n));
}

fn wave(num: i32) -> f32 {
    let fnum = f32(num) * params.frequency * 0.1 * f32(bars());
    return cos(fnum * 0.5) * cos(fnum * 0.13) * sin((fnum + 10.0) * 0.3) / 2.0 + 0.5;
}

fn drip(num: i32) -> f32 {
    return sin(f32(num) / f32(bars() - 1) * 3.141592) * params.drip_scale;
}

fn pos(num: i32) -> f32 {
    var p = mix(wave(num), rand(num), params.noise);
    if (params.noise == 0.0) { p = wave(num); }
    if (params.drip_scale != 0.0) { p += drip(num); }
    return p;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let bar = i32(uv.x * f32(bars()));
    let scale = 1.0 + pos(bar) * params.amplitude;
    // Unlike the original, the speeds are divided by the slowest column's, so that column
    // leaves at progress 1. In the original every column could be gone by mid-way (the
    // defaults make all of them at least twice as fast), leaving the second half still.
    var slowest = scale;
    for (var i = 0; i < bars(); i++) { slowest = min(slowest, 1.0 + pos(i) * params.amplitude); }
    let phase = progress * scale / max(slowest, 1e-3);
    if (phase + uv.y < 1.0) { return from_color(vec2f(uv.x, uv.y + phase)); }
    return to_color(uv);
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
