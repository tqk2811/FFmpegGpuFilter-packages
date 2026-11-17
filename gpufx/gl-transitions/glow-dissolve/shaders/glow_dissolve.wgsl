// Port of GlowDissolve.glsl from gl-transitions (author: hjm1fb, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlowDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let fr = from_color(uv);
    let to = to_color(uv);
    // Bright parts of the first clip burn last.
    let burn = 0.5 + 0.5 * dot(fr.rgb, vec3f(0.299, 0.587, 0.114));
    // Changed from the original, where the threshold ran from 0 to 1 over burn values from 0.5
    // to 1, so nothing moved during the first half: it now runs from just below the darkest
    // value, edge included, to just above the brightest one.
    let lw = max(params.line_width, 1e-4);
    let show = burn - mix(0.5 - lw - 0.002, 1.002, progress);
    if (show < 0.001) { return to; }
    let factor = 1.0 - smoothstep(0.0, lw, show);
    var glow = mix(params.spread_color.rgb, params.hot_color.rgb, factor);
    glow = pow(max(glow, vec3f(0.0)), vec3f(params.power)) * params.intensity;
    return vec4f(mix(fr.rgb, glow, factor * step(0.0001, progress)), fr.a);
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
