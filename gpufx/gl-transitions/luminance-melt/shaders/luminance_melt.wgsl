// Port of LuminanceMelt.glsl from gl-transitions (author: 0gust1, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LuminanceMelt.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn rand(co: vec2f) -> f32 {
    return fract(sin(dot(co, vec2f(12.9898, 78.233))) * 43758.5453);
}

// 2D simplex noise by Ian McEwan, Ashima Arts (MIT), https://github.com/ashima/webgl-noise
fn mod289_3(x: vec3f) -> vec3f { return x - floor(x * (1.0 / 289.0)) * 289.0; }
fn mod289_2(x: vec2f) -> vec2f { return x - floor(x * (1.0 / 289.0)) * 289.0; }
fn permute(x: vec3f) -> vec3f { return mod289_3(((x * 34.0) + 1.0) * x); }

fn snoise(v: vec2f) -> f32 {
    let cc = vec4f(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    var i = floor(v + dot(v, cc.yy));
    let x0 = v - i + dot(i, cc.xx);
    let i1 = select(vec2f(0.0, 1.0), vec2f(1.0, 0.0), x0.x > x0.y);
    var x12 = x0.xyxy + cc.xxzz;
    x12 = vec4f(x12.xy - i1, x12.zw);
    i = mod289_2(i);
    let p = permute(permute(i.y + vec3f(0.0, i1.y, 1.0)) + i.x + vec3f(0.0, i1.x, 1.0));
    var m = max(0.5 - vec3f(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), vec3f(0.0));
    m = m * m;
    m = m * m;
    let x = 2.0 * fract(p * cc.www) - 1.0;
    let h = abs(x) - 0.5;
    let ox = floor(x + 0.5);
    let a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    let g = vec3f(a0.x * x0.x + h.x * x0.y, a0.yz * x12.xz + h.yz * x12.yw);
    return 130.0 * dot(m, g);
}

fn luminance(c: vec4f) -> f32 { return c.r * 0.299 + c.g * 0.587 + c.b * 0.114; }

fn transition(p: vec2f, progress: f32) -> vec4f {
    let center = vec2f(1.0, f32(params.down));
    let dist = distance(center, p) - progress * exp(snoise(vec2f(p.x, 0.0)));
    let r = progress - rand(vec2f(p.x, 0.1));
    let l = luminance(from_color(p));
    let melts = select((l < params.threshold), (l > params.threshold), params.above != 0u);
    let m = select(progress * progress * progress, 1.0, dist <= r && melts);
    return mix(from_color(p), to_color(p), m);
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
