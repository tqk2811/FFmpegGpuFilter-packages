// Gray world, first pass: the thread at (k, y), k < 2, sums channel k + 1 (a, then b) of the
// log LMS "lab" color of row y and stores the f32 sum, bit for bit, in the RGBA8 texel.
fn pack(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

fn log_lms(c: vec3f) -> vec3f {
    let lms = vec3f(dot(vec3f(0.3811, 0.5783, 0.0402), c),
                    dot(vec3f(0.1967, 0.7244, 0.0782), c),
                    dot(vec3f(0.0241, 0.1288, 0.8444), c));
    return select(vec3f(-1024.0), log(max(lms, vec3f(1e-30))), lms > vec3f(0.0));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || id.x >= 2u) { return; }
    let w = i32(textureDimensions(src).x);
    let y = i32(id.y);
    var sum = 0.0;
    for (var x = 0; x < w; x++) {
        let l = log_lms(textureLoad(src, vec2i(x, y), 0).rgb);
        if (id.x == 0u) {
            sum += 0.40825 * l.x + 0.40825 * l.y - 0.816458 * l.z;
        } else {
            sum += 0.707 * l.x - 0.707 * l.y;
        }
    }
    gpufx_write(id, pack(sum));
}
