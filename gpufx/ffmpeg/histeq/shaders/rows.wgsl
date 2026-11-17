// Histeq, first pass: counts the luma histogram (FFmpeg's (55 r + 182 g + 19 b) >> 8 on 8-bit
// codes) of groups of rows. Texel number c = y * width + x holds bin c % 256 of group c / 256;
// the groups split the rows evenly, one row each when the picture is at least 256 wide. Counts
// are stored as u32 over RGBA8.
fn pack(u: u32) -> vec4f {
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = textureDimensions(src);
    let groups = max(min(s.y, s.x * s.y / 256u), 1u);
    let c = id.y * s.x + id.x;
    let g = c / 256u;
    if (g >= groups) { return; }
    let bin = c % 256u;
    let y0 = g * s.y / groups;
    let y1 = (g + 1u) * s.y / groups;
    var n = 0u;
    for (var y = y0; y < y1; y++) {
        for (var x = 0u; x < s.x; x++) {
            let v = vec3u(round(textureLoad(src, vec2u(x, y), 0).rgb * 255.0));
            let luma = (55u * v.r + 182u * v.g + 19u * v.b) >> 8u;
            n += select(0u, 1u, luma == bin);
        }
    }
    gpufx_write(id, pack(n));
}
