// Port of TvTurnOff.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TvTurnOff.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The screen at a time t of its power-off: 0 is the full picture, 1 is off.
fn screen(uv: vec2f, t: f32, is_from: bool) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let collapse = smoothstep(0.0, 0.4, t);
    let shrink = smoothstep(0.3, 0.65, t);
    let fade = 0.4 * smoothstep(0.75, 1.0, t);
    let radius = 0.01 * (1.0 - fade);
    // Half size of the picture, in height units.
    let size = vec2f(mix(0.5 * ratio, radius, shrink), mix(0.5, radius, collapse));
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let q = clamp(0.5 + 0.5 * p / size, vec2f(0.0), vec2f(1.0));
    let c = select(to_color(q), from_color(q), is_from);
    let white = smoothstep(0.4, 1.0, collapse);
    let light = vec4f(mix(min(c.rgb * (1.0 + 2.0 * collapse), vec3f(1.0)), vec3f(1.0), white), c.a);
    // Soft edges, outside the picture so that t = 0 is the exact picture.
    let d = abs(p) - size;
    let dist = length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
    let inside = clamp(1.0 - dist / 0.004, 0.0, 1.0);
    let mid = select(to_color(vec2f(0.5)), from_color(vec2f(0.5)), is_from);
    let halo = vec4f(mix(mix(mid.rgb, vec3f(1.0), 0.7), vec3f(1.0, 0.92, 0.8), shrink), mid.a);
    let h = 1.0 - exp(-2.0 * params.glow * white * exp(-max(dist, 0.0) / (0.02 + 0.04 * shrink)));
    let col = mix(params.color, halo, h * (1.0 - fade));
    return mix(col, light, inside * (1.0 - fade));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    if (progress < 0.5) { return screen(uv, 2.0 * progress, true); }
    return screen(uv, 2.0 - 2.0 * progress, false);
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
