// Port of Honeycomb.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Honeycomb.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Distance to the center of a pointy-top hexagon, 0.5 on the edges of a cell.
fn hex_dist(p_in: vec2f) -> f32 {
    let p = abs(p_in);
    return max(p.x, dot(p, vec2f(0.5, 0.8660254)));
}

fn rotation(a: f32) -> mat2x2f { return mat2x2f(cos(a), sin(a), -sin(a), cos(a)); }

// Coverage of a hexagon turned by a and scaled by s inside its cell, with soft edges of width e.
fn hex_mask(local: vec2f, s: f32, a: f32, e: f32) -> f32 {
    let r = (0.52 + e) * s;
    return 1.0 - smoothstep(r - e, r, hex_dist(rotation(-a) * local));
}

fn hex_uv(uv: vec2f, local: vec2f, cell_to_uv: vec2f, s: f32, a: f32) -> vec2f {
    return uv + cell_to_uv * (rotation(-a) * local / max(s, 0.001) - local);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Nearest hexagon center, on two interleaved rectangular grids (centers 1 apart).
    let to_cells = vec2f(ratio, 1.0) * params.size / min(ratio, 1.0);
    let p = (uv - 0.5) * to_cells;
    let grid = vec2f(1.0, 1.7320508);
    let a = (floor(p / grid) + 0.5) * grid;
    let b = (floor((p - 0.5 * grid) / grid) + 1.0) * grid;
    let center = select(b, a, dot(p - a, p - a) < dot(p - b, p - b));
    let local = p - center;
    let d = min(length(center / to_cells * vec2f(ratio, 1.0)) / (0.5 * length(vec2f(ratio, 1.0))), 1.0);
    let t = clamp((progress - 0.6 * d) / 0.4, 0.0, 1.0);
    let s = 1.0 - smoothstep(0.1, 1.0, t);
    let turn = 1.8 * t * (2.0 - t);
    var tile = from_color(hex_uv(uv, local, 1.0 / to_cells, s, turn));
    tile = vec4f(tile.rgb * (1.0 - 0.3 * t), tile.a);
    var below = to_color(uv);
    below = vec4f(below.rgb * (1.0 - 0.5 * hex_mask(local - vec2f(0.06, -0.08) * s, s, turn, 0.2)), below.a);
    return mix(below, tile, hex_mask(local, s, turn, 0.03));
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
