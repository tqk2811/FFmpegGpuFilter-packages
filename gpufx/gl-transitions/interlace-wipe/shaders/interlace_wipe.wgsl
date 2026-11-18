// Port of InterlaceWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InterlaceWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let lines = max(floor(params.rows), 1.0);
    let cols = max(floor(lines * ratio + 0.5), 1.0);
    // No more passes than fit: the first pass's blocks are never taller than the picture.
    let n = max(min(clamp(f32(params.passes), 2.0, 6.0), 1.0 + floor(log2(lines) + 0.01)), 2.0);
    let row = min(floor((1.0 - uv.y) * lines), lines - 1.0);
    let col = min(floor(uv.x * cols), cols - 1.0);
    let p = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
    // Each pass sweeps the whole frame in time tt; the passes start one after another and overlap a little.
    let tt = 1.5 / (n + 0.5);
    // The finest pass that has drawn this pixel wins: try them from the finest up.
    var best_b = 0.0;
    var light = 0.0;
    for (var i = 0; i < 6; i++) {
        let k = n - 1.0 - f32(i);
        if (k < 0.0) { break; }
        let b = floor(exp2(f32(i)) + 0.5);
        let u = clamp((p - (1.0 - tt) * k / (n - 1.0)) / tt, 0.0, 1.0);
        // The sweep runs on past the bottom of the frame until the glow behind it is gone.
        let glow_rows = max(1.5 * b, 0.05 * lines);
        let block_rows = ceil(lines / b);
        let sweep = u * (block_rows + glow_rows / b);
        let behind = sweep - floor(row / b) - (floor(col / b) + 1.0) / ceil(cols / b);
        if (behind >= -1e-4) {
            best_b = b;
            light = 1.0 - smoothstep(0.0, glow_rows, behind * b);
            break;
        }
    }
    if (best_b == 0.0) { return from_color(uv); }
    var c: vec4f;
    if (best_b <= 1.0) {
        c = to_color(uv);
    } else {
        let top = floor(row / best_b) * best_b;
        let left = floor(col / best_b) * best_b;
        c = to_color(vec2f((left + 0.5) / cols, 1.0 - (top + 0.5) / lines));
    }
    c = vec4f(c.rgb + 0.5 * params.glow * light * (1.0 - c.rgb), c.a);
    return c;
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
