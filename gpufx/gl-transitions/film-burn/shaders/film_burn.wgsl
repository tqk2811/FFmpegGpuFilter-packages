// Port of FilmBurn.glsl from gl-transitions (author: Anastasia Dunbar, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmBurn.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265358979323;
const REPEATS: f32 = 50.0;

fn sigmoid(x: f32, a: f32) -> f32 {
    if (x > 0.5) { return 1.0 - pow(2.0 - (x * 2.0), a) / 2.0; }
    return pow(x * 2.0, a) / 2.0;
}

fn rand1(co: f32) -> f32 {
    return fract(sin((co * 24.9898) + params.seed) * 43758.5453);
}

fn rand2(co: vec2f) -> f32 {
    return fract(sin(dot(co, vec2f(12.9898, 78.233))) * 43758.5453);
}

fn apow(a: f32, b: f32) -> f32 { return pow(abs(a), b) * sign(b); }

fn pow3(a: vec3f, b: vec3f) -> vec3f { return vec3f(apow(a.r, b.r), apow(a.g, b.g), apow(a.b, b.b)); }

fn smooth_mix(a: f32, b: f32, c: f32) -> f32 { return mix(a, b, sigmoid(c, 2.0)); }

fn random(co_in: vec2f, shft: f32) -> f32 {
    let co = co_in + 10.0;
    return smooth_mix(
        fract(sin(dot(co, vec2f(12.9898 + (floor(shft) * 0.5), 78.233 + params.seed))) * 43758.5453),
        fract(sin(dot(co, vec2f(12.9898 + (floor(shft + 1.0) * 0.5), 78.233 + params.seed))) * 43758.5453),
        fract(shft));
}

fn smooth_random(co: vec2f, shft: f32) -> f32 {
    return smooth_mix(
        smooth_mix(random(floor(co), shft), random(floor(co + vec2f(1.0, 0.0)), shft), fract(co.x)),
        smooth_mix(random(floor(co + vec2f(0.0, 1.0)), shft), random(floor(co + vec2f(1.0, 1.0)), shft), fract(co.x)),
        fract(co.y));
}

fn blended_color(p: vec2f, progress: f32) -> vec4f {
    return mix(from_color(p), to_color(p), sigmoid(progress, 10.0));
}

fn transition(p_in: vec2f, progress: f32) -> vec4f {
    var p = p_in;
    var f = vec3f(0.0);
    for (var i = 0.0; i < 13.0; i += 1.0) {
        f += sin(((p.x * rand1(i) * 6.0) + (progress * 8.0)) + rand1(i + 1.43))
            * sin(((p.y * rand1(i + 4.4) * 6.0) + (progress * 6.0)) + rand1(i + 2.4));
        let spot = vec2f(smooth_random(vec2f(progress * 1.3), i + 1.0), smooth_random(vec2f(progress * 0.5), i + 6.25));
        f += 1.0 - clamp(length(p - spot) * mix(20.0, 70.0, rand1(i)), 0.0, 1.0);
    }
    f += 4.0;
    f /= 11.0;
    f = pow3(f * vec3f(1.0, 0.7, 0.6), vec3f(1.0, 2.0 - sin(progress * PI), 1.3));
    f *= sin(progress * PI);

    p -= 0.5;
    p *= 1.0 + (smooth_random(vec2f(progress * 5.0), 6.3) * sin(progress * PI) * 0.05);
    p += 0.5;

    var blurred = vec4f(0.0);
    let blur_amount = sin(progress * PI) * 0.03;
    for (var i = 0.0; i < REPEATS; i += 1.0) {
        // degrees() as in the original, which feeds sin/cos with degrees of an angle in degrees.
        let a = degrees((i / REPEATS) * 360.0);
        let q = vec2f(cos(a), sin(a)) * (rand2(vec2f(i, p.x + p.y)) + blur_amount);
        blurred += blended_color(p + q * blur_amount, progress);
    }
    blurred /= REPEATS;
    return blurred + vec4f(f, 0.0);
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
