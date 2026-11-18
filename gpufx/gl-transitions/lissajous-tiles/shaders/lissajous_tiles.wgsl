// Port of LissajousTiles.glsl from gl-transitions (author: Boundless, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LissajousTiles.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const GRID: vec2f = vec2f(10.0, 10.0);
const TAU: f32 = 6.283185307;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    // The tiles leave and come back with zero speed, so the picture does not break apart at once.
    let p = 1.0 - pow(1.0 - smoothstep(0.0, 1.0, 1.0 - abs(1.0 - 2.0 * progress)), 3.0);
    // The last tile that covers this pixel (looping backwards, the first hit).
    for (var jb = 9; jb >= 0; jb--) {
        for (var ib = 9; ib >= 0; ib--) {
            let i = f32(ib) / GRID.x;
            let j = f32(jb) / GRID.y;
            let k = i / GRID.y + j;
            var uv0 = uv + vec2f(i, j) - 0.5 + 0.5 / GRID
                + vec2f(cos(k * TAU * params.freq.x + progress * 6.0 * params.speed),
                        sin(k * TAU * params.freq.y + progress * 6.0 * (1.0 + params.offset) * params.speed)) * params.zoom / 2.0;
            uv0 = mix(uv, uv0, p);
            if (uv0.x >= i && uv0.x < i + 1.0 / GRID.x && uv0.y >= j && uv0.y < j + 1.0 / GRID.y) {
                let fade = params.fade;
                let tile_mix = clamp(progress * ((1.0 + fade) * 2.0 * progress) - fade + k * fade, 0.0, 1.0);
                return mix(from_color(uv0), to_color(uv0), tile_mix);
            }
        }
    }
    // Between the tiles: `back_color` (the original leaves it transparent).
    return params.back_color;
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
