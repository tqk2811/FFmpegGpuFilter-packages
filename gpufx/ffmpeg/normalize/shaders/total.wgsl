// Normalize, second pass: the thread at (k, 0) reduces the row values of statistic k over the
// frame.
fn pack(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

fn unpack(c: vec4f) -> f32 {
    let b = vec4u(round(c * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || id.x >= 6u || id.y != 0u) { return; }
    let h = i32(textureDimensions(rows).y);
    let is_max = id.x >= 3u;
    var r = select(255.0, 0.0, is_max);
    for (var y = 0; y < h; y++) {
        let v = unpack(textureLoad(rows, vec2i(i32(id.x), y), 0));
        r = select(min(r, v), max(r, v), is_max);
    }
    gpufx_write(id, pack(r));
}
