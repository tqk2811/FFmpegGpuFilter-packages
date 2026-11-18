// Guided filter, last pass: box means of A and B over the subsampled grid, then
// out = mean(A) * I + mean(B) per output pixel, from the grid point of the pixel's cell.
fn up(t: vec4f) -> f32 {
    let b = vec4u(round(t * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}
fn sub_step() -> i32 { return select(1, params.sub, params.mode == 1); }
fn sub_radius() -> i32 {
    let n = sub_step();
    if (n == 1) { return params.radius; }
    if (params.radius >= n) { return params.radius / n; }
    return 1;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let n = sub_step();
    // Grid points of the coefficient passes, in the corner of the frame-sized textures.
    let g = (vec2i(gpufx_input_size(0u)) + n - 1) / n;
    let r = sub_radius();
    let p = vec2i(id.xy) / n;
    var sa = vec3f(0.0);
    var sb = vec3f(0.0);
    for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
            let q = clamp(p + vec2i(dx, dy), vec2i(0), g - 1);
            sa += vec3f(up(textureLoad(ar, q, 0)), up(textureLoad(ag, q, 0)), up(textureLoad(ab, q, 0)));
            sb += vec3f(up(textureLoad(br, q, 0)), up(textureLoad(bg, q, 0)), up(textureLoad(bb, q, 0)));
        }
    }
    let w = f32(2 * r + 1);
    let np = w * w;
    let c = gpufx_input_load(0u, vec2i(id.xy));
    // FFmpeg stores the float result in an integer: 8-bit codes, cut toward zero.
    let v = floor(clamp((sa / np) * (c.rgb * 255.0) + (sb / np) * 255.0, vec3f(0.0), vec3f(255.0)) + 1e-3) / 255.0;
    // planes: FFmpeg's bits on gbrp, 1 green, 2 blue, 4 red.
    let m = vec3<bool>((params.planes & 4) != 0, (params.planes & 1) != 0, (params.planes & 2) != 0);
    gpufx_write(id, vec4f(select(c.rgb, v, m), c.a));
}
