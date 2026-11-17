// Histeq, first pass: the thread at (k, y), k < 256, counts the pixels of row y whose luma
// (FFmpeg's (55 r + 182 g + 19 b) >> 8 on 8-bit codes) is k, stored as a u32 over RGBA8.
fn pack(u: u32) -> vec4f {
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || id.x >= 256u) { return; }
    let w = i32(textureDimensions(src).x);
    var n = 0u;
    for (var x = 0; x < w; x++) {
        let c = vec3u(round(textureLoad(src, vec2i(x, i32(id.y)), 0).rgb * 255.0));
        let luma = (55u * c.r + 182u * c.g + 19u * c.b) >> 8u;
        n += select(0u, 1u, luma == id.x);
    }
    gpufx_write(id, pack(n));
}
