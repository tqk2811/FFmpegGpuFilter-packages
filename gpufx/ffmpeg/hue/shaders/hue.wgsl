// FFmpeg hue (vf_hue.c) on BT.709 limited-range Y'CbCr: the chroma vector is rotated by `h`
// and scaled by `s`, the luma gets `b * 25.6` levels.
const KR: f32 = 0.2126;
const KB: f32 = 0.0722;
const KG: f32 = 1.0 - KR - KB;

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let c = textureLoad(src, vec2i(id.xy), 0);
    // 8-bit code values of limited-range Y'CbCr, chroma centred on 0
    let yl = KR * c.r + KG * c.g + KB * c.b;
    var y = 16.0 + 219.0 * yl;
    var u = 224.0 * (c.b - yl) / (2.0 * (1.0 - KB));
    var v = 224.0 * (c.r - yl) / (2.0 * (1.0 - KR));
    let a = radians(params.h);
    let hs = sin(a) * params.s;
    let hc = cos(a) * params.s;
    let nu = clamp(hc * u - hs * v, -128.0, 127.0);
    let nv = clamp(hs * u + hc * v, -128.0, 127.0);
    y = clamp(y + params.b * 25.6, 0.0, 255.0);
    let yy = (y - 16.0) / 219.0;
    let r = yy + 2.0 * (1.0 - KR) * nv / 224.0;
    let b = yy + 2.0 * (1.0 - KB) * nu / 224.0;
    let g = (yy - KR * r - KB * b) / KG;
    gpufx_write(id, vec4f(r, g, b, c.a));
}
