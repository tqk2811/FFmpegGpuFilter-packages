// Port of StaticWipe.glsl from gl-transitions (author: Ben Lucas, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StaticWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265359;

fn rnd(st: vec2f) -> f32 {
    return fract(sin(dot(st, vec2f(10.0, 70.0))) * 12345.5453123);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let span = params.max_static_span * pow(sin(PI * progress), 0.5);
    let edge = select(uv.y, 1.0 - uv.y, params.top_to_bottom != 0u);
    let mixed = mix(from_color(uv), to_color(uv), 1.0 - step(progress, edge));
    let envelope = smoothstep(progress - span, progress, edge) * (1.0 - smoothstep(progress, progress + span, edge));
    // Static where the picture is.
    let noise = vec4f(vec3f(rnd(uv * (1.0 + progress))), mixed.a);
    return mix(mixed, noise, envelope);
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
