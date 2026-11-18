// Port of BowTieHorizontal.glsl from gl-transitions (author: huynx, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BowTieHorizontal.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn check(p1: vec2f, p2: vec2f, p3: vec2f) -> f32 {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

fn in_triangle(pt: vec2f, p1: vec2f, p2: vec2f, p3: vec2f) -> bool {
    let b1 = check(pt, p1, p2) < 0.0;
    let b2 = check(pt, p2, p3) < 0.0;
    let b3 = check(pt, p3, p1) < 0.0;
    return b1 == b2 && b2 == b3;
}

fn blur_edge(bot1: vec2f, bot2: vec2f, top: vec2f, pt: vec2f) -> f32 {
    var dir = bot1 - top;
    let dist1 = abs(dot(normalize(vec2f(dir.y, -dir.x)), bot1 - pt));
    dir = bot2 - top;
    let min_dist = min(abs(dot(normalize(vec2f(dir.y, -dir.x)), bot2 - pt)), dist1);
    if (min_dist < 0.005) { return min_dist / 0.005; }
    return 1.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let l1 = vec2f(progress, 0.5);
    let l2 = vec2f(0.0, 0.5 - progress);
    let l3 = vec2f(0.0, 0.5 + progress);
    let r1 = vec2f(1.0 - progress, 0.5);
    let r2 = vec2f(1.0, 0.5 - progress);
    let r3 = vec2f(1.0, 0.5 + progress);
    if (in_triangle(uv, l1, l2, l3)) {
        if (progress < 0.1) { return from_color(uv); }
        if (uv.x < 0.5) { return mix(from_color(uv), to_color(uv), blur_edge(l2, l3, l1, uv)); }
        return to_color(uv);
    }
    if (in_triangle(uv, r1, r2, r3)) {
        if (uv.x >= 0.5) { return mix(from_color(uv), to_color(uv), blur_edge(r2, r3, r1, uv)); }
        return from_color(uv);
    }
    return from_color(uv);
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
