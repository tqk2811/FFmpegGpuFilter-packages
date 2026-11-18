// Port of SpiralBlockWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpiralBlockWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Position of the cell c (from the top left corner) along the spiral that runs clockwise
// from the top left corner of an n.x by n.y grid inward, from 0 to n.x * n.y - 1.
fn spiral_index(c: vec2f, n: vec2f) -> f32 {
    let k = min(min(c.x, c.y), min(n.x - 1.0 - c.x, n.y - 1.0 - c.y));
    let s = n - 2.0 * k;
    let l = c - k;
    let before = n.x * n.y - s.x * s.y;
    var along: f32;
    if (l.y == 0.0) { along = l.x; }
    else if (l.x == s.x - 1.0) { along = s.x - 1.0 + l.y; }
    else if (l.y == s.y - 1.0) { along = 2.0 * s.x + s.y - 3.0 - l.x; }
    else { along = 2.0 * (s.x - 1.0) + 2.0 * (s.y - 1.0) - l.y; }
    return before + along;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    var n = max(vec2f(f32(params.columns), f32(params.rows)), vec2f(1.0));
    var c = min(floor(vec2f(uv.x, 1.0 - uv.y) * n), n - 1.0);
    let inward = params.inward != 0u;
    let clockwise = params.clockwise != 0u;
    // The transposed spiral turns the other way from the same corner; walking outward reverses it too.
    if (clockwise != inward) {
        c = c.yx;
        n = n.yx;
    }
    let count = n.x * n.y;
    var i = spiral_index(c, n);
    if (!inward) { i = count - 1.0 - i; }

    let w = max(params.smoothness, 0.0) * count;
    let o = max(0.5 * (1.0 - w), 0.0);
    let x = progress * (count - 1.0 + 2.0 * o + w) - i - o;
    let m = select(step(0.0, x), smoothstep(0.0, w, x), w > 0.0);

    if (m <= 0.0) { return from_color(uv); }
    if (m >= 1.0) { return to_color(uv); }
    let a = from_color(uv);
    let b = to_color(uv);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    let col = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
    return select(vec4f(0.0), vec4f(col.rgb / max(col.a, 1e-6), col.a), col.a > 0.0);
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
