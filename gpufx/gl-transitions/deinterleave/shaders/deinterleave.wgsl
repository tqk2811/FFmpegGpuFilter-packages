// Port of Deinterleave.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Deinterleave.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;

fn gl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn ease3(x0: f32) -> f32 {
    let x = clamp(x0, 0.0, 1.0);
    let y = 2.0 - 2.0 * x;
    return select(1.0 - 0.5 * y * y * y, 4.0 * x * x * x, x < 0.5);
}

// Inverse of one round at amount a: in each block of b rows, even rows gather in its top half, odd
// rows in its bottom half. Returns (row, lighting); the lighting is -1 in the gaps.
fn unweave(z: f32, b: f32, a: f32, lit0: f32) -> vec2f {
    let bo = floor(z / b) * b;
    let lz = z - bo;
    let c = 1.0 - 0.5 * a;
    let off = a * (b - 1.0) * 0.5;
    // Rows of one parity are at least one row apart, so only the last one starting before lz can cover it.
    let io = floor((lz - off) / c);
    let ko = io - gl_mod(io + 1.0, 2.0);
    var f = lz - ko * c - off;
    if (ko >= 1.0 && ko < b && f < 1.0) { return vec2f(bo + ko + f, lit0); }
    let ie = floor(lz / c);
    let ke = ie - gl_mod(ie, 2.0);
    f = lz - ke * c;
    if (ke >= 0.0 && ke < b && f < 1.0) {
        // Dimming the even rows while they move makes the odd ones read as passing over them.
        return vec2f(bo + ke + f, lit0 * (1.0 - 0.25 * sin(PI * a)));
    }
    return vec2f(z, -1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let ss = clamp(f32(params.stages), 1.0, 4.0);
    // Built by doubling so block sizes stay exact integers.
    var copies = 1.0;
    for (var i = 0; i < 4; i++) {
        if (f32(i) < ss) { copies *= 2.0; }
    }
    // Rows per copy: at least 6, and at least 48 rows over the frame.
    let rows = max(6.0, 48.0 / copies);
    let mm = rows * copies;
    var z = (1.0 - uv.y) * mm;
    let band = floor(z / rows);
    let th = PI * ease3((progress - 0.43 - 0.07 * band / (copies - 1.0)) / 0.07);
    let ca = cos(th);
    let inc = ca < 0.0;
    // Each copy flips about its horizontal axis, seen from 2.5 frame heights away.
    let kp = sin(th) * sign(ca) / (2.5 * copies);
    let ys = fract(z / rows) - 0.5;
    let v = ys / max(abs(ca) - ys * kp, 1e-4);
    let x = 0.5 + (uv.x - 0.5) * (1.0 + v * kp);
    z = (band + 0.5 + clamp(v, -0.5, 0.4999)) * rows;
    let q = clamp(select(progress, 1.0 - progress, inc) / 0.43, 0.0, 1.0);
    // Rounds overlap so the rows never stop between them.
    let w = 1.0 / (0.6 * (ss - 1.0) + 1.0);
    var lit = 1.0;
    var b = 2.0 * rows;
    for (var i = 4; i >= 1; i--) {
        if (f32(i) > ss) { continue; }
        let r = unweave(z, b, ease3((q - 0.6 * w * f32(i - 1)) / w), lit);
        z = r.x;
        lit = r.y;
        if (lit < 0.0) { break; }
        b *= 2.0;
    }
    let p = vec2f(x, 1.0 - z / mm);
    var c = from_color(p);
    if (inc) { c = to_color(p); }
    c = vec4f(c.rgb * max(lit, 0.0) * (0.55 + 0.45 * abs(ca)), c.a);
    let aa = 400.0 / copies;
    let edge = clamp((0.5 - abs(v)) * aa + 1.0, 0.0, 1.0) * clamp((0.5 - abs(x - 0.5)) * 400.0 * ratio + 1.0, 0.0, 1.0);
    return mix(params.gap, c, step(0.0, lit) * edge);
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
