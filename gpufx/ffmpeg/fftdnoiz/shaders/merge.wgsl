// Puts the denoised channels together; channels left out by `planes` and alpha come from src.
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let c = vec2i(id.xy);
    let px = textureLoad(src, c, 0);
    let d = vec3f(textureLoad(dr, c, 0).r, textureLoad(dg, c, 0).r, textureLoad(db, c, 0).r);
    // FFmpeg's planes bits on gbrp: 1 G, 2 B, 4 R.
    let on = vec3<bool>((params.planes & 4) != 0, (params.planes & 1) != 0, (params.planes & 2) != 0);
    gpufx_write(id, vec4f(select(px.rgb, d, on), px.a));
}
