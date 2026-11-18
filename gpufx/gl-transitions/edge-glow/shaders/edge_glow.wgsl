// Port of EdgeGlow.glsl from gl-transitions (author: Woohyun Kim, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EdgeGlow.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Sobel-like edge strength around p, times the color at p.
fn edges(p: vec2f, incoming: bool) -> vec4f {
    // Changed from the original: the step is in pixels, not in a part of the frame, so the
    // edges show at every frame size.
    let o = params.thickness / globals.size;
    var c: array<vec3f, 9>;
    var alpha = 0.0;
    for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
            let q = p + o * vec2f(f32(i - 1), f32(j - 1));
            var col = from_color(q);
            if (incoming) { col = to_color(q); }
            c[3 * i + j] = col.rgb;
            if (i == 1 && j == 1) { alpha = col.a; }
        }
    }
    let dx = 2.0 * abs(c[7] - c[1]) + abs(c[2] - c[6]) + abs(c[8] - c[0]);
    let dy = 2.0 * abs(c[3] - c[5]) + abs(c[6] - c[8]) + abs(c[0] - c[2]);
    let delta = length(0.25 * (dx + dy) * 0.5);
    return vec4f(clamp(params.brightness * delta, 0.0, 1.0) * c[4], alpha);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let start = mix(from_color(uv), edges(uv, false), clamp(2.0 * progress, 0.0, 1.0));
    let end = mix(edges(uv, true), to_color(uv), clamp(2.0 * (progress - 0.5), 0.0, 1.0));
    return mix(start, end, progress);
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
