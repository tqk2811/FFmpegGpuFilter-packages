// Port of DirectionalScaled.glsl from gl-transitions (author: Thibaut Foussard, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DirectionalScaled.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The original leaves black around the scaled clips, which covers half the frame at the
// midpoint; here that area takes `background`, a near black by default.
const PI: f32 = 3.141592653589793;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let eased = pow(sin(progress * PI / 2.0), 3.0);
    let p = uv + eased * sign(params.direction);
    var f = fract(p);
    let s = 1.0 - (1.0 - 1.0 / max(params.scale, 0.01)) * sin(progress * PI);
    f = (f - 0.5) * s + 0.5;
    let mixer = step(0.0, p.y) * step(p.y, 1.0) * step(0.0, p.x) * step(p.x, 1.0);
    let col = mix(to_color(f), from_color(f), mixer);
    let border = step(0.0, f.x) * step(0.0, 1.0 - f.x) * step(0.0, f.y) * step(0.0, 1.0 - f.y);
    return select(params.background, col, border > 0.0);
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
