// Histeq, second pass: texel number k < 256 adds up the counts of every luma up to k over all
// row groups, giving the cumulative histogram (same texel numbering as the first pass).
fn pack(u: u32) -> vec4f {
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

fn unpack(c: vec4f) -> u32 {
    let b = vec4u(round(c * 255.0));
    return b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = textureDimensions(rows);
    let k = id.y * s.x + id.x;
    if (k >= 256u) { return; }
    let groups = max(min(s.y, s.x * s.y / 256u), 1u);
    var n = 0u;
    for (var g = 0u; g < groups; g++) {
        for (var b = 0u; b <= k; b++) {
            let c = g * 256u + b;
            n += unpack(textureLoad(rows, vec2u(c % s.x, c / s.x), 0));
        }
    }
    gpufx_write(id, pack(n));
}
