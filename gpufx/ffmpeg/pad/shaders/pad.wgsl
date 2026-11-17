// FFmpeg pad (vf_pad.c): the picture at (x, y) on a w x h canvas filled with `color`.
fn gpufx_output_size(out_index: u32) -> vec2u {
    let s = gpufx_input_size(0u);
    var w = u32(params.w);
    var h = u32(params.h);
    if (w == 0u) { w = s.x; }
    if (h == 0u) { h = s.y; }
    return max(vec2u(w, h), s);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let room = vec2i(globals.size) - s;
    var at = vec2i(params.x, params.y);
    if (at.x < 0) { at.x = room.x / 2; }
    if (at.y < 0) { at.y = room.y / 2; }
    at = clamp(at, vec2i(0), room);
    let p = vec2i(id.xy) - at;
    if (any(p < vec2i(0)) || any(p >= s)) {
        gpufx_write(id, params.color);
        return;
    }
    gpufx_write(id, textureLoad(src, p, 0));
}
