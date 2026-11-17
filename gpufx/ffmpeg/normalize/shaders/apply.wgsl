// Normalize, last pass: maps each channel's range linearly to the black and white points, with
// the same rounding as the lookup tables of FFmpeg's vf_normalize.c.
fn unpack(c: vec4f) -> f32 {
    let b = vec4u(round(c * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}

fn stat(k: i32) -> f32 {
    return unpack(textureLoad(total, vec2i(k, 0), 0));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let px = textureLoad(src, vec2i(id.xy), 0);
    let lo_in = vec3f(stat(0), stat(1), stat(2));
    let hi_in = vec3f(stat(3), stat(4), stat(5));
    let lo_all = min(min(lo_in.x, lo_in.y), lo_in.z);
    let hi_all = max(max(hi_in.x, hi_in.y), hi_in.z);
    let ind = params.independence;
    let st = params.strength;
    let lo_s = lo_in * ind + vec3f(lo_all) * (1.0 - ind);
    let hi_s = hi_in * ind + vec3f(hi_all) * (1.0 - ind);
    let lo_out = round(params.blackpt.rgb * 255.0) * st + lo_in * (1.0 - st);
    let hi_out = round(params.whitept.rgb * 255.0) * st + hi_in * (1.0 - st);
    let v = round(px.rgb * 255.0);
    let scale = (hi_out - lo_out) / (hi_s - lo_s);
    // C converts to int by truncation toward zero, then clips to 0..255.
    let mapped = trunc((v - lo_s) * scale + lo_out + 0.5);
    let o = select(mapped, trunc(lo_out), lo_s == hi_s);
    gpufx_write(id, vec4f(clamp(o, vec3f(0.0), vec3f(255.0)) / 255.0, px.a));
}
