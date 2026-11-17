// Port of Shockwave.glsl from gl-transitions (author: Gilad Levi, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Shockwave.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453123);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let size = max(params.tile_size, 0.008);
    let grid = max(vec2f(1.0), floor(vec2f(ratio, 1.0) / size));
    let cell = floor(uv * grid);
    let cell_uv = fract(uv * grid);
    let center_uv = (cell + 0.5) / grid;
    let sweep = mix(center_uv.x, 0.64 * center_uv.x + 0.36 * (1.0 - center_uv.y), clamp(params.diagonal, 0.0, 1.0));
    let noise = hash(cell);
    let start = 0.62 * sweep + 0.07 * noise;
    let t = clamp((progress - start) / 0.29, 0.0, 1.0);
    let movement = t * clamp(params.scatter, 0.0, 1.5);
    let wobble = hash(cell + vec2f(19.3, 7.7)) * 2.0 - 1.0;
    let drift = vec2f(0.65 * wobble, -0.95) * movement;
    let moving = cell_uv - drift;
    let inside = step(0.012, moving.x) * step(moving.x, 0.988) * step(0.012, moving.y) * step(moving.y, 0.988);
    let tile_shape = mix(1.0, inside, smoothstep(0.0, 0.13, t));
    let old_mask = tile_shape * (1.0 - smoothstep(0.48, 0.87, t));
    let old_uv = clamp(uv - drift / grid, vec2f(0.0), vec2f(1.0));
    var old_color = from_color(old_uv);
    let flare = sin(3.14159265 * t);
    let shift = vec2f(0.006, -0.002) * params.prism * flare;
    old_color.r = from_color(clamp(old_uv + shift, vec2f(0.0), vec2f(1.0))).r;
    var result = mix(to_color(uv), old_color, old_mask);
    let edge_distance = min(min(moving.x, 1.0 - moving.x), min(moving.y, 1.0 - moving.y));
    let edge = (1.0 - smoothstep(0.0, 0.10, edge_distance)) * inside;
    let rim = mix(vec3f(0.12, 0.95, 1.0), vec3f(1.0, 0.20, 0.65), hash(cell + vec2f(5.4, 28.6)));
    result = vec4f(clamp(result.rgb + rim * edge * flare * params.glow * old_mask * 0.60, vec3f(0.0), vec3f(1.0)), result.a);
    return result;
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
