// Port of OutlineTear.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/OutlineTear.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SPACING: f32 = 0.2;
const LO: f32 = 0.15;
const HI: f32 = 0.85;

fn ratio() -> f32 { return globals.size.x / globals.size.y; }

fn luma(p: vec2f) -> f32 {
    return dot(from_color(p).rgb, vec3f(0.299, 0.587, 0.114));
}

// Height of the strongest vertical brightness change in the column at knot i, on a coarse ladder.
fn knot(i: f32) -> f32 {
    let x = clamp(i * SPACING / ratio(), 0.0, 1.0);
    var prev = luma(vec2f(x, LO));
    // The tiny prior falls back to the middle on flat columns.
    var sw = 1e-4;
    var sy = 0.5e-4;
    for (var j = 1; j < 9; j++) {
        let y = mix(LO, HI, f32(j) / 8.0);
        let cur = luma(vec2f(x, y));
        let m = y - 0.5 * (HI - LO) / 8.0;
        let d = 4.0 * abs(cur - prev) * (1.0 - 1.2 * abs(m - 0.5));
        let w = d * d * d * d;
        sw += w;
        sy += w * m;
        prev = cur;
    }
    return sy / sw;
}

fn tri(x: f32) -> f32 { return abs(fract(x) - 0.5) - 0.25; }

// A quadratic B-spline through the knots keeps the path smooth whatever the texture.
fn outline(x: f32) -> f32 {
    let u = x * ratio() / SPACING;
    let i = floor(u + 0.5);
    let f = u - i + 0.5;
    let a = knot(i - 1.0);
    let b = knot(i);
    let c = knot(i + 1.0);
    return 0.5 * (1.0 - f) * (1.0 - f) * a + (0.5 + f - f * f) * b + 0.5 * f * f * c;
}

fn jag(x: f32) -> f32 {
    return params.roughness * (0.2 * sin(x * 13.0 + 1.1) + 0.5 * tri(x * 23.0 + sin(x * 7.0)) + 0.25 * tri(x * 61.0 + 0.6 * sin(x * 17.0)));
}

fn fibers(x: f32, seed: f32) -> f32 {
    return params.rim * (0.7 + 0.3 * sin(x * 41.0 + seed) + 0.4 * tri(x * 89.0 + seed));
}

fn torn(bg: vec4f, col: vec4f, e: f32, limit: f32, aa: f32, fiber: f32) -> vec4f {
    let paper = params.paper;
    let c = vec4f(mix(col.rgb, paper.rgb, clamp(0.5 + e / aa, 0.0, 1.0) * paper.a * fiber), col.a);
    return mix(bg, c, clamp(0.5 - (e - limit) / aa, 0.0, 1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = progress;
    let shadow = params.shadow;
    let xr = uv.x * ratio();
    let y0 = outline(uv.x);
    let edge = y0 + jag(xr);
    // The outline stays within [LO, HI], so this carries both halves out of the frame.
    let reach = HI + 0.5 * params.roughness + 2.0 * params.rim + 0.02;
    // The top peels from the left, the bottom from the right.
    let move_by = reach * p * p * (0.2 + 0.8 * p);
    let up = move_by * (1.0 + 0.12 * (1.0 - uv.x) * (1.0 - p));
    let down = move_by * (1.0 + 0.12 * uv.x * (1.0 - p));
    let fiber = smoothstep(0.0, 0.15, p);
    let aa = 0.0015;
    let ty = uv.y - up;
    let by = uv.y + down;
    let to = to_color(uv);
    let d = min(0.7 * (y0 - ty), 1.5 * (by - y0));
    let sh = shadow.a * fiber * (1.0 - smoothstep(0.7, 1.0, p)) * (1.0 - smoothstep(-0.02, 0.07, d));
    var c = vec4f(mix(to.rgb, shadow.rgb, sh), to.a);
    // The bottom half reaches under the top one so their seam is invisible at the start.
    c = torn(c, from_color(vec2f(uv.x, min(by, 1.0))), by - edge, fibers(xr, 2.0) * 1.4 * fiber + 0.003, aa, fiber);
    c = torn(c, from_color(vec2f(uv.x, max(ty, 0.0))), edge - ty, fibers(xr, 0.0) * fiber, aa, fiber);
    return c;
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
