// Port of SpeedLines.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SpeedLines.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.0012;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// How far the lines are in, from 0 (all out of the frame) to 1 (peak), for a line with random h:
// each line shoots in up to a little later than the others and retracts the same way.
fn reach_of(h: f32, progress: f32) -> f32 {
    let d = 0.05 * h;
    let a = 1.0 - clamp((progress - d) / 0.4, 0.0, 1.0);
    let b = clamp((progress - 0.5 - d) / 0.4, 0.0, 1.0);
    return (1.0 - a * a * a) * (1.0 - b * b * b);
}

// Coverage of one layer of lines: n angular cells around the focus point (a in 0..1), at most one
// tapered line per cell. e is the elliptical radius (1 at the edges of the frame), r the radius in
// frame heights, ee the elliptical radius where the ray leaves the frame.
fn layer(a: f32, e: f32, r: f32, n: f32, seed: f32, ee: f32, progress: f32) -> f32 {
    // (a can be exactly 1, which is cell 0 again)
    let x = floor(a * n);
    let cell = x - n * floor(x / n);
    let h1 = hash12(vec2f(cell, seed));
    let h2 = hash12(vec2f(cell, seed + 7.0));
    let h3 = hash12(vec2f(cell, seed + 13.0));
    let on = step(0.22, h1);
    let h4 = hash12(vec2f(cell, seed + 50.0 + floor(progress * 12.0)));
    // A share of the way from the frame's edge to the focus point, so the burst stays even off-center.
    let len = 1.0 - 0.85 * h2 * h2 - 0.15 * h4;
    let tip_peak = ee * (1.0 - (1.0 - params.focus) * (0.55 + 0.45 * len));
    let tip = mix(ee + 0.05, tip_peak, reach_of(h3, progress));
    let t = clamp((e - tip) / max(ee * (0.2 + 0.5 * h2), 1e-4), 0.0, 1.0);
    let cell_width = 2.0 * PI * r / n;
    // Its position across the cell, and its width, kept so its antialiased edges stay in the cell.
    let offset = 0.3 + 0.4 * h3;
    let width = min(cell_width * (0.06 + 0.22 * h1) * sqrt(t), (0.5 - abs(offset - 0.5)) * cell_width - AA);
    let across = abs(fract(a * n) - offset) * cell_width;
    return on * (1.0 - smoothstep(width - AA, width + AA, across)) * step(tip, e);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let line_color = params.line_color;
    let p = progress;
    let asp = vec2f(ratio, 1.0);
    let d = (uv - center) * asp;
    let r = length(d);
    // (nudged off zero, where atan is undefined)
    let a = atan2(d.y, d.x + 1e-6) / (2.0 * PI) + 0.5;
    // Elliptical radius, following the shape of the frame.
    let e = length((uv - center) * 2.0);
    // Where the ray from the focus point through this pixel leaves the frame, so every line enters at once.
    let w = uv - center;
    let room = vec2f(select(center.x, 1.0 - center.x, w.x > 0.0), select(center.y, 1.0 - center.y, w.y > 0.0));
    let exits = room / max(abs(w), vec2f(1e-6));
    let ee = e * min(exits.x, exits.y);

    var k = 1.0 - smoothstep(0.5, 1.0, p);
    if (p < 0.5) { k = smoothstep(0.0, 0.5, p); }
    let s = 1.0 - params.zoom * k * k;
    let q = center + (uv - center) * s;
    var c = to_color(q);
    if (p < 0.5) { c = from_color(q); }

    // Two interleaved layers of lines so that their spacing looks random.
    let n = max(floor(params.density), 2.0);
    var l = layer(a, e, r, n, 1.0, ee, p);
    l = max(l, layer(fract(a + 0.5 / n), e, r, n, 31.0, ee, p));
    l *= line_color.a;

    var pc = vec4f(c.rgb * c.a, c.a);
    pc = pc * (1.0 - l) + vec4f(line_color.rgb, 1.0) * l;
    if (pc.a > 0.0) { return vec4f(pc.rgb / pc.a, pc.a); }
    return vec4f(0.0);
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
