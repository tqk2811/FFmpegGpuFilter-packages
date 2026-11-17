// Port of BandWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BandWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;

// How far band i has wiped in (0..1) at position a along the bands (0..l), alternate bands
// entering from opposite ends.
fn band_mask(i: f32, n: f32, a: f32, l: f32, s: f32, progress: f32) -> f32 {
    let k = select(n - 1.0 - i, i, params.vertical != 0u);
    let g = clamp(params.stagger, 0.0, 0.95);
    var t = clamp((progress - g * k / max(n - 1.0, 1.0)) / (1.0 - g), 0.0, 1.0);
    t = mix(t, t * t * (3.0 - 2.0 * t), 0.5);
    let x = select(a, l - a, i - 2.0 * floor(i / 2.0) > 0.5);
    // The edge starts fully before the band and ends fully past it.
    let c = mix(-s, l + s, t);
    return 1.0 - smoothstep(c - s, c + s, x);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let vertical = params.vertical != 0u;
    let n = f32(max(params.bands, 1));
    // along: position along the bands, in frame heights; across: position across them (0..1).
    let along = select(uv.x * ratio, uv.y, vertical);
    let across = select(uv.y, uv.x, vertical);
    let l = select(ratio, 1.0, vertical);
    let aa_across = select(AA, AA / ratio, vertical);
    let s = max(params.smoothness, AA);
    let f = across * n;
    let i = clamp(floor(f), 0.0, n - 1.0);
    var m = band_mask(i, n, along, l, s, progress);
    // Near a cut between two bands, blend with the neighbor band over a pixel or so.
    let fr = f - i;
    let edge = min(fr, 1.0 - fr) / n;
    if (edge < aa_across) {
        let j = clamp(select(i + 1.0, i - 1.0, fr < 0.5), 0.0, n - 1.0);
        m = mix(band_mask(j, n, along, l, s, progress), m, 0.5 + 0.5 * smoothstep(0.0, aa_across, edge));
    }
    let a = from_color(uv);
    let b = to_color(uv);
    if (m <= 0.0) { return a; }
    if (m >= 1.0) { return b; }
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
