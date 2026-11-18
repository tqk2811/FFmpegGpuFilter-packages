// Port of ButterflyWaveScrawler.glsl from gl-transitions (author: mandubian, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ButterflyWaveScrawler.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265358979323846264;

fn compute(p: vec2f, progress: f32, center: vec2f) -> f32 {
    let o = p * sin(progress * params.amplitude) - center;
    let h = vec2f(1.0, 0.0);
    // Butterfly polar function. acos is clamped: GLSL returns NaN outside -1..1 like WGSL,
    // where the original's dot product leaves that range the picture is not moved.
    let theta = acos(clamp(dot(o, h), -1.0, 1.0)) * params.waves;
    let s = sin((2.0 * theta - PI) / 24.0);
    let s2 = s * s;
    return (exp(cos(theta)) - 2.0 * cos(4.0 * theta) + s2 * s2 * s) / 10.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = uv;
    let inv = 1.0 - progress;
    let disp = compute(p, progress, vec2f(0.5, 0.5));
    let tex_to = to_color(p + inv * disp);
    let from_center = from_color(p + progress * disp);
    let tex_from = vec4f(
        from_color(p + progress * disp * (1.0 - params.color_separation)).r,
        from_center.g,
        from_color(p + progress * disp * (1.0 + params.color_separation)).b,
        from_center.a);
    return tex_to * progress + tex_from * inv;
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
