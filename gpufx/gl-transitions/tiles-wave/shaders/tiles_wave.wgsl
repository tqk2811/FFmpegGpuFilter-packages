// Port of TilesWave.glsl from gl-transitions (author: numb3r23, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TilesWave.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Squeezes the tile coordinate t (0..1) to the band left by s, as in the original.
fn squeeze(t: f32, s: f32, den: f32) -> f32 {
    if (t < 0.5) { return (t - s) * 0.5 / den; }
    return (t - 0.5) * 0.5 / den + 0.5;
}

// Changed from the original, where the gap beside a turning tile showed the same clip
// unchanged: it shows that clip darkened, as the shadow behind the tile.
fn gap(c: vec4f) -> vec4f { return vec4f(c.rgb * 0.35, c.a); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let count = vec2f(max(f32(params.columns), 1.0), max(f32(params.rows), 1.0));
    let flip_x = params.flip_x != 0u;
    let flip_y = params.flip_y != 0u;
    let tile_size = 1.0 / count;
    let in_tile = fract(uv * count);
    let tile = floor(uv * count);
    let n = count.x * count.y;
    // Tile after tile, up each column from the bottom left, then across.
    let order = tile.y + tile.x * count.y;
    // Changed from the original, where each tile turned over in half a tile step, so the
    // wave looked like a plain block wipe: each tile takes `duration` steps, and the
    // last one finishes at the end.
    let dur = max(params.duration, 0.5);
    let time = 0.5 * clamp((progress * (n - 1.0 + dur) - order) / dur, 0.0, 1.0);
    let s = 1.0 - abs(cos(time * 3.1415926));
    var tc = in_tile;
    if (s <= 0.5) {
        // The tile of the first clip narrows to a line (the divisions are kept off zero).
        let den = max(0.5 - s, 1e-5);
        if (flip_x) {
            if (tc.x < s || tc.x > 1.0 - s) { return gap(from_color(uv)); }
            tc.x = squeeze(tc.x, s, den);
        }
        if (flip_y) {
            if (tc.y < s || tc.y > 1.0 - s) { return gap(from_color(uv)); }
            tc.y = squeeze(tc.y, s, den);
        }
        return from_color(tile * tile_size + tc * tile_size);
    }
    // Then the tile of the second clip opens from the line, mirrored as its back.
    let den = min(0.5 - s, -1e-5);
    if (flip_x) {
        if (tc.x > s || tc.x < 1.0 - s) { return gap(to_color(uv)); }
        tc.x = 1.0 - squeeze(tc.x, s, den);
    }
    if (flip_y) {
        if (tc.y > s || tc.y < 1.0 - s) { return gap(to_color(uv)); }
        tc.y = 1.0 - squeeze(tc.y, s, den);
    }
    return to_color(tile * tile_size + tc * tile_size);
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
