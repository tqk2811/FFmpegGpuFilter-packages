// Port of SquaresWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SquaresWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const CENTER: vec2f = vec2f(0.5, 0.5);

fn transition(p: vec2f, progress: f32) -> vec4f {
    var v = normalize(params.direction);
    v /= abs(v.x) + abs(v.y);
    let d = v.x * CENTER.x + v.y * CENTER.y;
    let offset = params.smoothness;
    let pr = smoothstep(-offset, 0.0, v.x * p.x + v.y * p.y - (d - 0.5 + progress * (1.0 + offset)));
    let squarep = fract(p * max(round(params.squares), vec2f(1.0)));
    let squaremin = vec2f(pr / 2.0);
    let squaremax = vec2f(1.0 - pr / 2.0);
    let a = (1.0 - step(progress, 0.0)) * step(squaremin.x, squarep.x) * step(squaremin.y, squarep.y)
        * step(squarep.x, squaremax.x) * step(squarep.y, squaremax.y);
    return mix(from_color(p), to_color(p), a);
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
