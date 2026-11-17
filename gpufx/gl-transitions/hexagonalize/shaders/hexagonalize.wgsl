// Port of Hexagonalize.glsl from gl-transitions (author: Fernando Kuteken, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Hexagonalize.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Hexagonal math from http://www.redblobgames.com/grids/hexagons/
fn round_hex(h: vec3f) -> vec3f {
    var q = floor(h.x + 0.5);
    var r = floor(h.y + 0.5);
    var s = floor(h.z + 0.5);
    let dq = abs(q - h.x);
    let dr = abs(r - h.y);
    let ds = abs(s - h.z);
    if (dq > dr && dq > ds) { q = -r - s; } else if (dr > ds) { r = -q - s; } else { s = -q - r; }
    return vec3f(q, r, -q - r);
}

fn hex_from_point(point_in: vec2f, size: f32, ratio: f32) -> vec3f {
    var point = point_in;
    point.y /= ratio;
    point = (point - 0.5) / size;
    let q = (sqrt(3.0) / 3.0) * point.x + (-1.0 / 3.0) * point.y;
    let r = 2.0 / 3.0 * point.y;
    return round_hex(vec3f(q, r, -q - r));
}

fn point_from_hex(h: vec3f, size: f32, ratio: f32) -> vec2f {
    let x = (sqrt(3.0) * h.x + (sqrt(3.0) / 2.0) * h.y) * size + 0.5;
    let y = ((3.0 / 2.0) * h.y) * size + 0.5;
    return vec2f(x, y * ratio);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dist = 2.0 * min(progress, 1.0 - progress);
    if (params.steps > 0) { dist = ceil(dist * f32(params.steps)) / f32(params.steps); }
    let size = (sqrt(3.0) / 3.0) * dist / params.horizontal_hexagons;
    var point = uv;
    if (dist > 0.0) { point = point_from_hex(hex_from_point(uv, size, ratio), size, ratio); }
    return mix(from_color(point), to_color(point), progress);
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
