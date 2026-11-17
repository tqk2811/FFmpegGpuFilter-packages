// Port of PerlinDissolve.glsl from gl-transitions (author: Rich Harris, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PerlinDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// GLSL mod: the result has the sign of y.
fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn random(co: vec2f) -> f32 {
    let dt = dot(co, vec2f(params.seed, 78.233));
    return fract(sin(gmod(dt, 3.14)) * 43758.5453);
}

// 2D noise based on Morgan McGuire @morgan3d, https://www.shadertoy.com/view/4dS3Wd
fn noise(st: vec2f) -> f32 {
    let i = floor(st);
    let f = fract(st);
    let a = random(i);
    let b = random(i + vec2f(1.0, 0.0));
    let c = random(i + vec2f(0.0, 1.0));
    let d = random(i + vec2f(1.0, 1.0));
    let u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let sm = params.smoothness;
    let n = noise(uv * params.scale);
    let p = mix(-sm, 1.0 + sm, progress);
    let q = smoothstep(p - sm, p + sm, n);
    return mix(from_color(uv), to_color(uv), 1.0 - q);
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
