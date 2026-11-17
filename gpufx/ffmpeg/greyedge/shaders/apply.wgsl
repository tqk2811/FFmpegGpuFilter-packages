// Grey edge, last pass: normalizes the light estimate to unit length and divides each channel
// by it (times sqrt(3)), rounding as FFmpeg does.
fn unpack(c: vec4f) -> f32 {
    let b = vec4u(round(c * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let px = textureLoad(src, vec2i(id.xy), 0);
    // FFmpeg refuses a one-tap kernel with a derivative; the picture is left as it is.
    if (params.difford > 0 && floor(3.0 * params.sigma + 0.5) == 0.0) {
        gpufx_write(id, px);
        return;
    }
    var light = vec3f(unpack(textureLoad(total, vec2i(0, 0), 0)),
                      unpack(textureLoad(total, vec2i(1, 0), 0)),
                      unpack(textureLoad(total, vec2i(2, 0), 0)));
    let len = length(light);
    if (len == 0.0) {
        light = vec3f(1.0);
    } else {
        light = light / len;
        light = select(light, vec3f(1.0), light == vec3f(0.0));
    }
    let code = round(px.rgb * 255.0);
    let o = trunc(code / (light * 1.73205080757) + 0.5);
    gpufx_write(id, vec4f(clamp(o, vec3f(0.0), vec3f(255.0)) / 255.0, px.a));
}
