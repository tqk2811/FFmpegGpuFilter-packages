// Port of DirectionalWarp.glsl from gl-transitions (author: pschroen, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DirectionalWarp.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const CENTER: vec2f = vec2f(0.5, 0.5);

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let sm = params.smoothness;
    var v = normalize(params.direction);
    v /= abs(v.x) + abs(v.y);
    let d = v.x * CENTER.x + v.y * CENTER.y;
    let m = 1.0 - smoothstep(-sm, 0.0, v.x * uv.x + v.y * uv.y - (d - 0.5 + progress * (1.0 + sm)));
    return mix(from_color((uv - 0.5) * (1.0 - m) + 0.5), to_color((uv - 0.5) * m + 0.5), m);
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
