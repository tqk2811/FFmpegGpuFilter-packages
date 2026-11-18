// Port of PlasmaDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PlasmaDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = from_color(uv);
    let b = to_color(uv);
    let sc = max(params.scale, 0.0) * 2.0 * PI;
    // Measured in square pixels, so the waves are not stretched.
    let p = (uv - 0.5) * vec2f(ratio, 1.0) * sc;
    // The folded plasma changes by at most 0.9 * flow per unit of progress, slower than the
    // threshold, so the reveal never goes back.
    let t = clamp(params.flow, 0.0, 1.0) * progress * 0.5;
    var v = sin(p.x * 0.6 + t) + sin(p.y * 0.8 - t * 0.8) + sin((p.x * 0.5 + p.y * 0.7) * 0.7 + t * 0.6)
        + sin(length(p - vec2f(0.15, -0.1) * sc) * 0.9 - t * 1.2);
    v = abs(fract(v * 0.25 + 0.5) * 2.0 - 1.0);
    let s = max(params.smoothness, 0.001);
    let threshold = mix(-s, 1.0 + s, progress);
    let m = 1.0 - smoothstep(threshold - s, threshold + s, v);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    let col = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
    if (col.a <= 0.0) { return vec4f(0.0); }
    // A light along the edge, adding nothing to the alpha.
    let glow = 4.0 * m * (1.0 - m) * max(params.edge_strength, 0.0);
    return vec4f(col.rgb / col.a + params.edge_color.rgb * glow, col.a);
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
