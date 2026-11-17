// Grey edge, third pass: the thread at (k, 0) reduces the rows of channel k into the light
// estimate (maximum, or Minkowski norm).
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
    if (!gpufx_in_bounds(id) || id.x >= 3u || id.y != 0u) { return; }
    let h = i32(textureDimensions(rows).y);
    var r = 0.0;
    for (var y = 0; y < h; y++) {
        let v = unpack(textureLoad(rows, vec2i(i32(id.x), y), 0));
        if (params.minknorm == 0) { r = max(r, v); } else { r += v; }
    }
    if (params.minknorm != 0) { r = pow(r, 1.0 / f32(params.minknorm)); }
    gpufx_write(id, pack(r));
}
