// Port of SnakeBlockWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SnakeBlockWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let a = from_color(uv);
    let b = to_color(uv);
    let vertical = params.vertical != 0u;
    let g = max(vec2f(f32(params.columns), f32(params.rows)), vec2f(1.0));
    let cell = min(floor(vec2f(uv.x, 1.0 - uv.y) * g), g - 1.0);
    let lines = select(g.y, g.x, vertical);
    let len = select(g.x, g.y, vertical);
    let line = select(cell.y, cell.x, vertical);
    var pos = select(cell.x, cell.y, vertical);
    if (line - 2.0 * floor(line / 2.0) > 0.5) { pos = len - 1.0 - pos; }
    let order = line * len + pos;
    // Block k fades in from k to k + w, on a timeline from 0 to n - 1 + w.
    let n = lines * len;
    let w = max(params.smoothness, 0.001);
    let m = clamp((progress * (n - 1.0 + w) - order) / w, 0.0, 1.0);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    let c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
    return vec4f(0.0);
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
