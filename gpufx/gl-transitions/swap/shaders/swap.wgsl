// Port of Swap.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Swap.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Where no clip is drawn: transparent.
const BLACK: vec4f = vec4f(0.0);

fn in_bounds(p: vec2f) -> bool {
    return all(vec2f(0.0) < p) && all(p < vec2f(1.0));
}

fn project(p: vec2f) -> vec2f {
    return p * vec2f(1.0, -1.2) + vec2f(0.0, -0.02);
}

fn bg_color(pfr_in: vec2f, pto_in: vec2f) -> vec4f {
    var c = BLACK;
    let pfr = project(pfr_in);
    if (in_bounds(pfr)) { c += mix(BLACK, from_color(pfr), params.reflection * mix(1.0, 0.0, pfr.y)); }
    let pto = project(pto_in);
    if (in_bounds(pto)) { c += mix(BLACK, to_color(pto), params.reflection * mix(1.0, 0.0, pto.y)); }
    return c;
}

fn transition(p: vec2f, progress: f32) -> vec4f {
    let perspective = params.perspective;
    let depth = params.depth;
    var size = mix(1.0, depth, progress);
    var persp = perspective * progress;
    let pfr = (p + vec2f(0.0, -0.5)) * vec2f(size / (1.0 - perspective * progress), size / (1.0 - size * persp * p.x)) + vec2f(0.0, 0.5);
    size = mix(1.0, depth, 1.0 - progress);
    persp = perspective * (1.0 - progress);
    let pto = (p + vec2f(-1.0, -0.5)) * vec2f(size / (1.0 - perspective * (1.0 - progress)), size / (1.0 - size * persp * (0.5 - p.x))) + vec2f(1.0, 0.5);
    if (progress < 0.5) {
        if (in_bounds(pfr)) { return from_color(pfr); }
        if (in_bounds(pto)) { return to_color(pto); }
    }
    if (in_bounds(pto)) { return to_color(pto); }
    if (in_bounds(pfr)) { return from_color(pfr); }
    return bg_color(pfr, pto);
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
