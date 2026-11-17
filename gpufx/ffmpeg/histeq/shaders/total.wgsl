// Histeq, second pass: the thread at (k, 0) adds up the counts of every luma up to k over all
// rows, giving the cumulative histogram.
fn pack(u: u32) -> vec4f {
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

fn unpack(c: vec4f) -> u32 {
    let b = vec4u(round(c * 255.0));
    return b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || id.x >= 256u || id.y != 0u) { return; }
    let h = i32(textureDimensions(rows).y);
    var n = 0u;
    for (var y = 0; y < h; y++) {
        for (var k = 0; k <= i32(id.x); k++) {
            n += unpack(textureLoad(rows, vec2i(k, y), 0));
        }
    }
    gpufx_write(id, pack(n));
}
