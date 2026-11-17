// FFmpeg eq (vf_eq.c): the picture is turned into BT.709 limited-range Y'CbCr, every plane goes
// through FFmpeg's curve, then back to RGB.
const KR: f32 = 0.2126;
const KB: f32 = 0.0722;
const KG: f32 = 1.0 - KR - KB;

fn to_ycbcr(c: vec3f) -> vec3f {
    let y = KR * c.r + KG * c.g + KB * c.b;
    let cb = (c.b - y) / (2.0 * (1.0 - KB));
    let cr = (c.r - y) / (2.0 * (1.0 - KR));
    return vec3f(16.0 + 219.0 * y, 128.0 + 224.0 * cb, 128.0 + 224.0 * cr) / 255.0;
}

fn to_rgb(v: vec3f) -> vec3f {
    let y = (v.x * 255.0 - 16.0) / 219.0;
    let cb = (v.y * 255.0 - 128.0) / 224.0;
    let cr = (v.z * 255.0 - 128.0) / 224.0;
    let r = y + 2.0 * (1.0 - KR) * cr;
    let b = y + 2.0 * (1.0 - KB) * cb;
    let g = (y - KR * r - KB * b) / KG;
    return vec3f(r, g, b);
}

// create_lut of vf_eq.c, without its 8-bit table.
fn curve(x: f32, contrast: f32, brightness: f32, gamma: f32) -> f32 {
    var v = contrast * (x - 0.5) + 0.5 + brightness;
    if (v <= 0.0) { return 0.0; }
    v = v * (1.0 - params.gamma_weight) + pow(v, 1.0 / gamma) * params.gamma_weight;
    return min(v, 1.0);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = textureLoad(src, vec2i(id.xy), 0);
    let v = to_ycbcr(s.rgb);
    let y = curve(v.x, params.contrast, params.brightness, params.gamma * params.gamma_g);
    let cb = curve(v.y, params.saturation, 0.0, sqrt(params.gamma_b / params.gamma_g));
    let cr = curve(v.z, params.saturation, 0.0, sqrt(params.gamma_r / params.gamma_g));
    gpufx_write(id, vec4f(to_rgb(vec3f(y, cb, cr)), s.a));
}
