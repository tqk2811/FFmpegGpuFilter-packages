// Morpho, second pass: opening is the dilation of the erosion, closing the erosion of the
// dilation; the other modes combine the first pass with the picture.
fn over(t: i32, p: vec2i, dilate: bool) -> vec3f {
    let s = vec2i(textureDimensions(src));
    let k = min(vec2i(textureDimensions(structure)), vec2i(63));
    let c = (k - 1) / 2;
    var acc = vec3f(select(2.0, -1.0, dilate));
    for (var y = 0; y < k.y; y++) {
        for (var x = 0; x < k.x; x++) {
            let on = textureLoad(structure, vec2i(x, y), 0).rgb > vec3f(0.0);
            if (!any(on)) { continue; }
            let q = p + vec2i(x, y) - c;
            if (any(q < vec2i(0)) || any(q >= s)) { continue; }
            var v: vec3f;
            if (t == 0) { v = textureLoad(eroded, q, 0).rgb; } else { v = textureLoad(dilated, q, 0).rgb; }
            if (dilate) { acc = select(acc, max(acc, v), on); } else { acc = select(acc, min(acc, v), on); }
        }
    }
    let own = select(textureLoad(eroded, p, 0).rgb, textureLoad(dilated, p, 0).rgb, t == 1);
    return select(acc, own, (acc > vec3f(1.5)) | (acc < vec3f(-0.5)));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let p = vec2i(id.xy);
    let a = textureLoad(src, p, 0);
    let e = textureLoad(eroded, p, 0).rgb;
    let d = textureLoad(dilated, p, 0).rgb;
    var o: vec3f;
    switch params.mode {
        case 0: { o = e; }
        case 1: { o = d; }
        case 2: { o = over(0, p, true); }
        case 3: { o = over(1, p, false); }
        case 4: { o = d - e; }
        case 5: { o = a.rgb - over(0, p, true); }
        default: { o = over(1, p, false) - a.rgb; }
    }
    gpufx_write(id, vec4f(o, a.a));
}
