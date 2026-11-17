// FFmpeg transpose (vf_transpose.c): output pixel (x, y) reads input pixel (y, x), mirrored on
// the axes the direction asks for.
fn passes_through(s: vec2u) -> bool {
    return (params.passthrough == 1 && s.y >= s.x) || (params.passthrough == 2 && s.x >= s.y);
}

fn gpufx_output_size(out_index: u32) -> vec2u {
    let s = gpufx_input_size(0u);
    if (passes_through(s)) { return s; }
    return s.yx;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let o = vec2i(id.xy);
    if (passes_through(vec2u(s))) {
        gpufx_write(id, textureLoad(src, o, 0));
        return;
    }
    var p = o.yx;
    if (params.dir == 1 || params.dir == 3) { p.y = s.y - 1 - p.y; }
    if (params.dir == 2 || params.dir == 3) { p.x = s.x - 1 - p.x; }
    gpufx_write(id, textureLoad(src, p, 0));
}
