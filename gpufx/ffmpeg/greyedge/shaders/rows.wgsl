// Grey edge, second pass: the thread at (k, y), k < 3, reduces channel k of row y: the
// maximum for minknorm 0, else the sum of (n / 255)^minknorm.
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
    if (!gpufx_in_bounds(id) || id.x >= 3u) { return; }
    let w = i32(textureDimensions(nr).x);
    let p = f32(params.minknorm);
    var r = 0.0;
    for (var x = 0; x < w; x++) {
        let q = vec2i(x, i32(id.y));
        var v: f32;
        switch id.x {
            case 0u: { v = unpack(textureLoad(nr, q, 0)); }
            case 1u: { v = unpack(textureLoad(ng, q, 0)); }
            default: { v = unpack(textureLoad(nb, q, 0)); }
        }
        if (params.minknorm == 0) { r = max(r, v); } else { r += pow(v / 255.0, p); }
    }
    gpufx_write(id, pack(r));
}
