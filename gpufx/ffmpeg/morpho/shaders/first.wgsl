// Morpho, first pass: erosion (minimum) and dilation (maximum) of the picture over the
// structuring element, per R, G, B channel (FFmpeg vf_morpho.c).
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let k = min(vec2i(textureDimensions(structure)), vec2i(63));
    let c = (k - 1) / 2;
    let p = vec2i(id.xy);
    var lo = vec3f(2.0);
    var hi = vec3f(-1.0);
    for (var y = 0; y < k.y; y++) {
        for (var x = 0; x < k.x; x++) {
            let on = textureLoad(structure, vec2i(x, y), 0).rgb > vec3f(0.0);
            if (!any(on)) { continue; }
            let q = p + vec2i(x, y) - c;
            // Pixels outside the picture are left out, as in FFmpeg.
            if (any(q < vec2i(0)) || any(q >= s)) { continue; }
            let v = textureLoad(src, q, 0).rgb;
            lo = select(lo, min(lo, v), on);
            hi = select(hi, max(hi, v), on);
        }
    }
    let a = textureLoad(src, p, 0);
    // An empty element leaves the channel as it is.
    lo = select(a.rgb, lo, hi >= vec3f(0.0));
    hi = select(a.rgb, hi, hi >= vec3f(0.0));
    gpufx_write(id, vec4f(lo, a.a));
    gpufx_write1(id, vec4f(hi, a.a));
}
