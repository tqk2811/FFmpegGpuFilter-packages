// Port of WhipSpin.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WhipSpin.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const SAMPLES: i32 = 24;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return mix(m, 2.0 - m, step(vec2f(1.0), m));
}

// The camera roll at time t: the first clip speeds up until the middle, then the second,
// already turning, slows down to rest.
fn roll_angle(t: f32) -> f32 {
    let half_turn = PI * params.turns;
    if (t < 0.5) {
        let x = 2.0 * t;
        return half_turn * x * x * x;
    }
    let x = 2.0 - 2.0 * t;
    return -half_turn * x * x * x;
}

fn transition(uv: vec2f, p: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let h = 1.0 - abs(2.0 * p - 1.0);
    let shutter = params.blur * 0.1 * h;
    let scale = 1.0 + params.zoom * h * h * h;
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let jitter = hash(uv * vec2f(ratio, 1.0) * 731.0);
    var color = vec3f(0.0);
    var weight = vec3f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        let s = (f32(i) + jitter) / f32(SAMPLES) - 0.5;
        let t = clamp(p + s * shutter, 0.0, 1.0);
        let a = roll_angle(t);
        let c = cos(a);
        let sn = sin(a);
        let r = vec2f(c * q.x + sn * q.y, -sn * q.x + c * q.y) / scale;
        let suv = mirror(r / vec2f(ratio, 1.0) + 0.5);
        let col = select(to_color(suv), from_color(suv), t < 0.5);
        // Red trails behind and blue leads along the arc: the channels split with the speed.
        let w = max(vec3f(1.0 - 4.0 * params.chroma * s, 1.0, 1.0 + 4.0 * params.chroma * s), vec3f(0.0));
        color += col.rgb * col.a * w;
        weight += col.a * w;
        alpha += col.a;
    }
    return vec4f(color / max(weight, vec3f(1e-5)), alpha / f32(SAMPLES));
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
