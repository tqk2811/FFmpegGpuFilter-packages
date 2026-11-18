// Port of MicroBrickCascade.glsl from gl-transitions (author: Gilad Levi, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MicroBrickCascade.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash12(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453123);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let s = max(params.tile_size, 0.004);
    let grid_count = max(vec2f(1.0), floor(vec2f(ratio, 1.0) / s));
    let tile = floor(uv * grid_count);
    let tile_uv = fract(uv * grid_count);
    let tile_center = (tile + 0.5) / grid_count;
    let wave = mix(tile_center.x, 0.65 * tile_center.x + 0.35 * (1.0 - tile_center.y), clamp(params.diagonal, 0.0, 1.0));
    // Random stagger, so the wall does not break apart too uniformly.
    let r1 = hash12(tile);
    let r2 = hash12(tile + vec2f(19.1, 7.3));
    let r3 = hash12(tile + vec2f(41.7, 13.9));
    let start = 0.08 + 0.60 * wave + params.stagger * 0.12 * (r1 - 0.5);
    let t = clamp((progress - start) / 0.28, 0.0, 1.0);
    let sideways = (r2 * 2.0 - 1.0) * params.drift * t;
    let downward = params.fall * t * t;
    let moved = tile_uv - vec2f(sideways, -downward);
    let inside = step(0.0, moved.x) * step(moved.x, 1.0) * step(0.0, moved.y) * step(moved.y, 1.0);
    let fade_start = mix(0.40, 0.15, params.softness);
    let fade_end = mix(0.95, 0.65, params.softness);
    let visibility = inside * (1.0 - smoothstep(fade_start, fade_end, t));
    // The tile carries its picture fragment with it.
    let shifted = uv - vec2f(sideways, -downward) / grid_count;
    let from_c = from_color(clamp(shifted, vec2f(0.0), vec2f(1.0)));
    let to_c = to_color(uv);
    var color = mix(to_c, from_c, visibility);
    let edge_distance = min(min(moved.x, 1.0 - moved.x), min(moved.y, 1.0 - moved.y));
    let edge = (1.0 - smoothstep(0.0, 0.08, edge_distance)) * inside;
    let sparkle = sin(t * 3.14159265) * params.glow * visibility;
    let edge_color = mix(vec3f(0.12, 0.90, 1.0), vec3f(1.0, 0.35, 0.65), r3);
    color = vec4f(clamp(color.rgb + edge_color * edge * sparkle * 0.45, vec3f(0.0), vec3f(1.0)), color.a);
    return color;
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
