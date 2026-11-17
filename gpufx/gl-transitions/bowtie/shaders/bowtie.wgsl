// Port of BowTie.glsl from gl-transitions (author: KMojek, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BowTie.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const HEIGHT: f32 = 0.5;

fn check(p1: vec2f, p2: vec2f, p3: vec2f) -> f32 {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

fn in_triangle(pt: vec2f, p1: vec2f, p2: vec2f, p3: vec2f) -> bool {
    let b1 = check(pt, p1, p2) < 0.0;
    let b2 = check(pt, p2, p3) < 0.0;
    let b3 = check(pt, p3, p1) < 0.0;
    return b1 == b2 && b2 == b3;
}

fn first_half(uv: vec2f, prog: f32) -> vec4f {
    let adjust = params.adjust;
    if (uv.y < 0.5) {
        if (in_triangle(uv, vec2f(0.0, prog - HEIGHT), vec2f(1.0, prog - HEIGHT), vec2f(adjust, prog))) { return to_color(uv); }
    } else {
        if (in_triangle(uv, vec2f(0.0, 1.0 - prog + HEIGHT), vec2f(1.0, 1.0 - prog + HEIGHT), vec2f(adjust, 1.0 - prog))) { return to_color(uv); }
    }
    return from_color(uv);
}

fn second_half(uv: vec2f, prog: f32) -> vec4f {
    let adjust = params.adjust;
    if (uv.x > adjust) {
        let tip = vec2f(mix(adjust, 1.0, 2.0 * (prog - 0.5)), 0.5);
        if (in_triangle(uv, vec2f(prog + HEIGHT, 1.0), vec2f(prog + HEIGHT, 0.0), tip)) { return from_color(uv); }
    } else {
        let tip = vec2f(mix(adjust, 0.0, 2.0 * (prog - 0.5)), 0.5);
        if (in_triangle(uv, vec2f(1.0 - prog - HEIGHT, 1.0), vec2f(1.0 - prog - HEIGHT, 0.0), tip)) { return from_color(uv); }
    }
    return to_color(uv);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    if (params.reverse != 0u) {
        if (progress < 0.5) { return second_half(uv, 1.0 - progress); }
        return first_half(uv, 1.0 - progress);
    }
    if (progress < 0.5) { return first_half(uv, progress); }
    return second_half(uv, progress);
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
