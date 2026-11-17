// Gray world, last pass: removes the frame mean of the a and b channels of the log LMS color
// and converts back to RGB (FFmpeg vf_grayworld.c).
fn unpack(c: vec4f) -> f32 {
    let b = vec4u(round(c * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let src_px = textureLoad(src, vec2i(id.xy), 0);
    let c = src_px.rgb;
    let lms = vec3f(dot(vec3f(0.3811, 0.5783, 0.0402), c),
                    dot(vec3f(0.1967, 0.7244, 0.0782), c),
                    dot(vec3f(0.0241, 0.1288, 0.8444), c));
    let l = select(vec3f(-1024.0), log(max(lms, vec3f(1e-30))), lms > vec3f(0.0));
    var lab = vec3f(0.5774 * (l.x + l.y + l.z),
                    0.40825 * l.x + 0.40825 * l.y - 0.816458 * l.z,
                    0.707 * l.x - 0.707 * l.y);
    lab.y -= unpack(textureLoad(total, vec2i(0, 0), 0));
    lab.z -= unpack(textureLoad(total, vec2i(1, 0), 0));
    let m = exp(vec3f(0.57735 * lab.x + 0.40825 * lab.y + 0.707 * lab.z,
                      0.57735 * lab.x + 0.40825 * lab.y - 0.707 * lab.z,
                      0.57735 * lab.x - 0.8165 * lab.y));
    let rgb = vec3f(dot(vec3f(4.4679, -3.5873, 0.1193), m),
                    dot(vec3f(-1.2186, 2.3809, -0.1624), m),
                    dot(vec3f(0.0497, -0.2439, 1.2045), m));
    gpufx_write(id, vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), src_px.a));
}
