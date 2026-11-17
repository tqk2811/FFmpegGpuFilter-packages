// Gray world, second pass: the thread at (k, 0) adds up the row sums of channel k and stores
// the frame mean, bit for bit, in its texel.
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
    if (!gpufx_in_bounds(id) || id.x >= 2u || id.y != 0u) { return; }
    let s = vec2i(textureDimensions(rows));
    var sum = 0.0;
    for (var y = 0; y < s.y; y++) {
        sum += unpack(textureLoad(rows, vec2i(i32(id.x), y), 0));
    }
    gpufx_write(id, pack(sum / f32(s.x * s.y)));
}
