// Port of Bounce.glsl from gl-transitions (author: Adrian Purser, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Bounce.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265358;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let shadow = params.shadow_colour;
    let height = params.shadow_height;
    let stime = sin(progress * PI / 2.0);
    let phase = progress * PI * params.bounces;
    let y = abs(cos(phase)) * (1.0 - stime);
    let d = uv.y - y;
    let to = to_color(uv);
    // The shadow's alpha is its strength: it darkens, it does not make the picture transparent,
    // and it falls on the incoming picture only, not on its transparent areas.
    let k = step(d, height) * (1.0 - mix(((d / height) * shadow.a) + (1.0 - shadow.a), 1.0, smoothstep(0.95, 1.0, progress))) * to.a;
    return mix(
        mix(to, vec4f(shadow.rgb, 1.0), k),
        from_color(vec2f(uv.x, uv.y + (1.0 - y))),
        step(d, 0.0));
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
