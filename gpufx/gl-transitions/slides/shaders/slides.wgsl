// Port of Slides.glsl from gl-transitions (author: Mark Craig, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Slides.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv0: vec2f, progress: f32) -> vec4f {
    let slide_in = params.slide_in != 0u;
    let rad = max(select(1.0 - progress, progress, slide_in), 1e-5);
    let h = 0.5 - rad / 2.0;
    let e = 1.0 - rad;
    var c = vec2f(h, 0.0);
    switch (params.position) {
        case 1: { c = vec2f(e, h); }
        case 2: { c = vec2f(h, e); }
        case 3: { c = vec2f(0.0, h); }
        case 4: { c = vec2f(e, 0.0); }
        case 5: { c = vec2f(e, e); }
        case 6: { c = vec2f(0.0, e); }
        case 7: { c = vec2f(0.0, 0.0); }
        case 8: { c = vec2f(h, h); }
        default: {}
    }
    // The original measures the box from the top left.
    let uv = vec2f(uv0.x, 1.0 - uv0.y);
    if (uv.x >= c.x && uv.x <= c.x + rad && uv.y >= c.y && uv.y <= c.y + rad) {
        let uv2 = vec2f((uv.x - c.x) / rad, 1.0 - (uv.y - c.y) / rad);
        return select(from_color(uv2), to_color(uv2), slide_in);
    }
    return select(to_color(uv0), from_color(uv0), slide_in);
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
