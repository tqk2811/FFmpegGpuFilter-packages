// FFmpeg rotate (vf_rotate.c): every output pixel reads the input at its position turned back by
// `angle` around the centres of both pictures.
fn gpufx_output_size(out_index: u32) -> vec2u {
    let s = vec2f(gpufx_input_size(0u));
    let c = abs(cos(params.angle));
    let n = abs(sin(params.angle));
    // rotw(a) and roth(a) of FFmpeg
    let fit = vec2u(round(vec2f(s.x * c + s.y * n, s.x * n + s.y * c)));
    var w = u32(max(params.ow, 0));
    var h = u32(max(params.oh, 0));
    if (params.ow == 0) { w = u32(s.x); }
    if (params.oh == 0) { h = u32(s.y); }
    if (params.ow < 0) { w = fit.x; }
    if (params.oh < 0) { h = fit.y; }
    return vec2u(w, h);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2f(textureDimensions(src));
    let d = vec2f(id.xy) - (globals.size - 1.0) * 0.5;
    let c = cos(params.angle);
    let n = sin(params.angle);
    let p = vec2f(c * d.x + n * d.y, -n * d.x + c * d.y) + (s - 1.0) * 0.5;
    // FFmpeg keeps a pixel whose integer position is within one pixel of the picture, and reads
    // it clamped to the edge, so the border of the rotated picture is one pixel wider.
    let i = vec2i(floor(p));
    if (any(i < vec2i(-1)) || any(i > vec2i(s))) {
        // fillcolor=none: the pixel is not written, as FFmpeg leaves it unpainted.
        if (params.nofill == 0u) { gpufx_write(id, params.fillcolor); }
        return;
    }
    let m = vec2i(s) - 1;
    if (params.bilinear == 0u) {
        gpufx_write(id, textureLoad(src, clamp(i, vec2i(0), m), 0));
        return;
    }
    let f = p - vec2f(i);
    let a00 = textureLoad(src, clamp(i, vec2i(0), m), 0);
    let a10 = textureLoad(src, clamp(i + vec2i(1, 0), vec2i(0), m), 0);
    let a01 = textureLoad(src, clamp(i + vec2i(0, 1), vec2i(0), m), 0);
    let a11 = textureLoad(src, clamp(i + vec2i(1, 1), vec2i(0), m), 0);
    gpufx_write(id, mix(mix(a00, a10, f.x), mix(a01, a11, f.x), f.y));
}
