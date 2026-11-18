// Port of DreamyZoom.glsl from gl-transitions (author: Zeh Fernando, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DreamyZoom.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const DEG2RAD: f32 = 0.03926990816987241548078304229099;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let first = progress < 0.5;
    let phase = select((progress - 0.5) * 2.0, progress * 2.0, first);
    let rot = params.rotation * DEG2RAD;
    let angle_offset = select(mix(-rot, 0.0, phase), mix(0.0, rot, phase), first);
    let new_scale = select(mix(params.scale, 1.0, phase), mix(1.0, params.scale, phase), first);
    var p = (uv - vec2f(0.5)) / new_scale * vec2f(ratio, 1.0);
    let angle = atan2(p.y, p.x) + angle_offset;
    let dist = length(p);
    p = vec2f(cos(angle) * dist / ratio + 0.5, sin(angle) * dist + 0.5);
    let c = select(to_color(p), from_color(p), first);
    // The flash lights up the image, not the transparent areas around it.
    return vec4f(c.rgb + select(mix(1.0, 0.0, phase), mix(0.0, 1.0, phase), first), c.a);
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
