// Remap (FFmpeg vf_remap.c): the output has the size of xmap; each output pixel copies the
// source pixel at (xmap, ymap), or takes the fill color when that is outside the source.
fn gpufx_output_size(out_index: u32) -> vec2u {
    return gpufx_input_size(1u);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let p = vec2i(id.xy);
    let s = vec2i(textureDimensions(src));
    let ys = vec2i(textureDimensions(ymap));
    let x = i32(round(textureLoad(xmap, p, 0).r * params.map_max));
    // A smaller ymap reads as outside the source past its edge.
    var y = s.y;
    if (all(p < ys)) { y = i32(round(textureLoad(ymap, p, 0).r * params.map_max)); }
    if (x < s.x && y < s.y) {
        gpufx_write(id, textureLoad(src, vec2i(x, y), 0));
    } else {
        gpufx_write(id, params.fill);
    }
}
