// Port of PolkaDotsCurtain.glsl from gl-transitions (author: bobylito, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PolkaDotsCurtain.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    // `center` is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    // Unlike the original (`progress / distance`), the radius is scaled so the dots at the
    // farthest corner close at progress 1, and eased in. In the original they all closed
    // well before the end, which then held the second clip still.
    let far = length(max(center, 1.0 - center));
    let radius = progress * progress * 0.70711 * far / distance(uv, center);
    let next = distance(fract(uv * params.dots), vec2f(0.5, 0.5)) < radius;
    return select(from_color(uv), to_color(uv), next);
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
