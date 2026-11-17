// Port of Mosaic.glsl from gl-transitions (author: Xaychru, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Mosaic.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265358979323;

fn rand(v: vec2f) -> f32 {
    return fract(sin(dot(v, vec2f(12.9898, 78.233))) * 43758.5453);
}

// GLSL's mat2(cos, -sin, sin, cos) * v (column major).
fn rotate(v: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * v.x + s * v.y, -s * v.x + c * v.y);
}

fn cos_interpolation(x: f32) -> f32 {
    return -cos(x * PI) / 2.0 + 0.5;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = uv - 0.5;
    var rp = p;
    let rpr = progress * 2.0 - 1.0;
    let z = -(rpr * rpr * 2.0) + 3.0;
    rp *= abs(z);
    let ci = cos_interpolation(progress);
    rp += mix(vec2f(0.5, 0.5), vec2f(f32(params.endx) + 0.5, f32(params.endy) + 0.5), ci * ci);
    var mrp = rp - floor(rp);
    let cell = floor(rp);
    let on_end = i32(cell.x) == params.endx && i32(cell.y) == params.endy;
    if (!on_end) {
        let ang = f32(i32(rand(cell) * 4.0)) * 0.5 * PI;
        mrp = vec2f(0.5) + rotate(mrp - vec2f(0.5), ang);
    }
    if (on_end || rand(cell) > 0.5) { return to_color(mrp); }
    return from_color(mrp);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let uv = gpufx_uv(id);
    // Exact clips at both ends, whatever the formula rounds to.
    if (params.progress <= 0.0) { gpufx_write(id, textureSampleLevel(first, smp, uv, 0.0)); return; }
    if (params.progress >= 1.0) { gpufx_write(id, textureSampleLevel(second, smp, uv, 0.0)); return; }
    gpufx_write(id, transition(vec2f(uv.x, 1.0 - uv.y), params.progress));
}
