// Port of RotateScaleVanish.glsl from gl-transitions (author: Mark Craig, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RotateScaleVanish.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TWOPI: f32 = 6.283185307179586476925286766559;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let res = vec2f(globals.size.x / globals.size.y, 1.0);
    let reverse = params.reverse_effect != 0u;
    let t = select(progress, 1.0 - progress, reverse);
    let theta = select(-TWOPI * t, TWOPI * t, params.reverse_rotation != 0u);
    let c1 = cos(theta);
    let s1 = sin(theta);
    let rad = max(0.00001, 1.0 - t);
    let xc1 = (uv.x - 0.5) * res.x;
    let yc1 = (uv.y - 0.5) * res.y;
    var uv2 = vec2f((xc1 * c1 - yc1 * s1) / rad + res.x / 2.0, (xc1 * s1 + yc1 * c1) / rad + res.y / 2.0);
    let color_to = select(to_color(uv), from_color(uv), reverse);
    var col3: vec4f;
    if (uv2.x >= 0.0 && uv2.x <= res.x && uv2.y >= 0.0 && uv2.y <= res.y) {
        uv2 /= res;
        col3 = select(from_color(uv2), to_color(uv2), reverse);
    } else {
        // Transparent around the shrinking picture.
        col3 = select(color_to, vec4f(0.0), params.fade_in_second != 0u);
    }
    return (1.0 - t) * col3 + t * color_to;
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
