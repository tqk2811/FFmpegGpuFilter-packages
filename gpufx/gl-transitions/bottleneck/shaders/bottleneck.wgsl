// Port of Bottleneck.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Bottleneck.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

fn transition(uv: vec2f, t: f32) -> vec4f {
    let nk = clamp(params.neck, 0.05, 0.5);
    let e = mix(t, t * t * (3.0 - 2.0 * t), 0.6);
    // Margin so the change at the neck starts above and ends below the frame.
    let margin = 0.6 * nk;
    let dy = (uv.y - mix(1.0 + margin, -margin, e)) / nk;
    let env = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.75, 1.0, t));
    let pinch = clamp(params.depth, 0.3, 0.97) * env * exp(-dy * dy);
    let w = 1.0 - pinch;
    let x = (uv.x - 0.5) / w;
    // The sheet is drawn into the neck, so the picture beside it stretches along y.
    let q = mirror(vec2f(x + 0.5, uv.y + 0.25 * nk * dy * pinch));
    var c = mix(from_color(q), to_color(q), smoothstep(-0.15, 0.15, dy));
    let across = sqrt(max(1.0 - 4.0 * x * x, 0.0));
    let sx = (x + 0.17) / max(0.07, 0.004 / w);
    c = vec4f(c.rgb * mix(1.0, 0.35 + 0.65 * across, pinch) + 0.3 * pinch * exp(-sx * sx), c.a);
    let inside = 1.0 - smoothstep(0.5, 0.5 + 0.003 / w, abs(x));
    var bg = params.background;
    bg = vec4f(bg.rgb * mix(0.55, 1.0, clamp((abs(uv.x - 0.5) - 0.5 * w) / 0.06, 0.0, 1.0)), bg.a);
    return mix(bg, c, inside);
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
