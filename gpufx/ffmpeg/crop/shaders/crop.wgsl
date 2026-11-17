// FFmpeg crop (vf_crop.c): copies the w x h rectangle at (x, y), kept inside the picture.
fn crop_size(s: vec2u) -> vec2u {
    var w = u32(params.w);
    var h = u32(params.h);
    if (w == 0u) { w = s.x; }
    if (h == 0u) { h = s.y; }
    return min(vec2u(w, h), s);
}

fn gpufx_output_size(out_index: u32) -> vec2u {
    return crop_size(gpufx_input_size(0u));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let o = vec2i(globals.size);
    let room = s - o;
    var at = vec2i(params.x, params.y);
    // FFmpeg evaluates (in_w - out_w) / 2 and rounds it half to even (lrint), as WGSL round does.
    if (at.x < 0) { at.x = i32(round(f32(room.x) / 2.0)); }
    if (at.y < 0) { at.y = i32(round(f32(room.y) / 2.0)); }
    at = clamp(at, vec2i(0), room);
    gpufx_write(id, textureLoad(src, at + vec2i(id.xy), 0));
}
