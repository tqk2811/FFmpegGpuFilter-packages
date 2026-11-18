// Port of Rolls.glsl from gl-transitions (author: Mark Craig, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Rolls.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const M_PI: f32 = 3.14159265358979323846;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let res = vec2f(globals.size.x / globals.size.y, 1.0);
    let corner = clamp(params.corner, 0, 3);
    let down = params.roll_down != 0u;
    var theta: f32;
    var uvi = uv;
    if (corner == 0) { theta = select(-M_PI, M_PI, down) / 2.0 * progress; uvi.x = 1.0 - uv.x; }
    else if (corner == 1) { theta = select(-M_PI, M_PI, down) / 2.0 * progress; }
    else if (corner == 2) { theta = select(M_PI, -M_PI, down) / 2.0 * progress; uvi.y = 1.0 - uv.y; }
    else { theta = select(M_PI, -M_PI, down) / 2.0 * progress; uvi = 1.0 - uv; }
    let c1 = cos(theta);
    let s1 = sin(theta);
    var uv2 = vec2f(uvi.x * res.x * c1 - uvi.y * res.y * s1, uvi.x * res.x * s1 + uvi.y * res.y * c1);
    if (uv2.x >= 0.0 && uv2.x <= res.x && uv2.y >= 0.0 && uv2.y <= res.y) {
        uv2 /= res;
        if (corner == 0) { uv2.x = 1.0 - uv2.x; }
        else if (corner == 2) { uv2.y = 1.0 - uv2.y; }
        else if (corner == 3) { uv2 = 1.0 - uv2; }
        return from_color(uv2);
    }
    return to_color(uv);
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
