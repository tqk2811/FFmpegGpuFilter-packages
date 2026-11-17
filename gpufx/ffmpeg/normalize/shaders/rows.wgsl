// Normalize, first pass: the thread at (k, y), k < 6, finds the minimum (k < 3) or maximum
// (k >= 3) 8-bit code of channel k % 3 along row y and stores it as the bits of an f32.
fn pack(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || id.x >= 6u) { return; }
    let w = i32(textureDimensions(src).x);
    let c = id.x % 3u;
    let is_max = id.x >= 3u;
    var r = select(255.0, 0.0, is_max);
    for (var x = 0; x < w; x++) {
        let v = round(textureLoad(src, vec2i(x, i32(id.y)), 0)[c] * 255.0);
        r = select(min(r, v), max(r, v), is_max);
    }
    gpufx_write(id, pack(r));
}
