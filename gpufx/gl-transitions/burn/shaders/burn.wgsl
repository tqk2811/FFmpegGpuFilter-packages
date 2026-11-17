// Port of BurnThrough.glsl from gl-transitions (author: liubailin2020@gmail.com, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BurnThrough.glsl
// The noise is based on Morgan McGuire's https://www.shadertoy.com/view/4dS3Wd.
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn random(st: vec2f) -> f32 {
    return fract(sin(dot(st, vec2f(12.9898, 78.233))) * 43758.5453123);
}

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

fn fbm(st_in: vec2f) -> f32 {
    var st = st_in;
    var value = 0.0;
    var amplitude = 0.5;
    for (var i = 0; i < 4; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let a = from_color(uv);
    let b = to_color(uv);
    let n = fbm(uv * 4.0);
    let e = progress * 1.05 - 0.05;
    let l = smoothstep(e, e + 0.05, n);
    let edge = (1.0 - l) * l * 5.0;
    return mix(b, a, l) + vec4f(params.burn_color.rgb, 0.0) * edge;
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
