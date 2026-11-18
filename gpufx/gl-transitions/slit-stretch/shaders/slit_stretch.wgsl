// Port of SlitStretch.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SlitStretch.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let t = progress;
    let q = t * t * (3.0 - 2.0 * t);
    let ratio = globals.size.x / globals.size.y;
    let horizontal = params.horizontal != 0u;
    let asp = vec2f(ratio, 1.0);
    // Work with the slits along x and the pull along y.
    var p = (uv - 0.5) * asp;
    if (horizontal) { p = p.yx; }
    let sy = 1.0 + params.stretch * q;
    let ys = clamp(p.y / (sy * select(1.0, ratio, horizontal)), -0.5, 0.5);
    let hw = 0.5 * select(ratio, 1.0, horizontal);
    let wf = 1.0 - 0.7 * params.neck * q * (1.0 - 4.0 * ys * ys);
    // No edge on the frame's border at the start.
    let side = (hw * wf - abs(p.x)) / (0.003 * min(1.0, 200.0 * q) + 1e-7);
    p.x /= wf;
    let a = 0.5 * params.size;
    let b = 0.22 * params.size * sy;
    let j = floor(p.y / b + 0.5);
    let xo = (j - 2.0 * floor(j / 2.0)) * a;
    let i = floor((p.x - xo) / (2.0 * a) + 0.5);
    let c = vec2f(i * 2.0 * a + xo, j * b);
    var d = p - c;
    // Check the two neighbouring rows too: the diamonds interlock.
    let d2 = p - vec2f(c.x + select(-a, a, p.x > c.x), c.y + select(-b, b, p.y > c.y));
    if (abs(d2.x) / a + abs(d2.y) / b < abs(d.x) / a + abs(d.y) / b) { d = d2; }

    // The hole: a slit that opens into a diamond, slightly larger than the cell at the end.
    let grow = 1.0 + 0.12 * q;
    let ha = max(a * mix(0.72, 1.0, q) * grow, 1e-4);
    let hh = max(b * sqrt(q) * grow, 1e-5);
    let f = abs(d.x) / ha + abs(d.y) / hh - 1.0;
    let dist = f / sqrt(1.0 / (ha * ha) + 1.0 / (hh * hh));
    let e = 0.004;
    let hole = max(smoothstep(0.0, e, e * q * q * q * q - dist), clamp(0.5 - side, 0.0, 1.0));

    var img = vec4f(0.0);
    if (hole < 1.0) {
        var sp = vec2f(p.x, p.y / sy);
        if (horizontal) { sp = sp.yx; }
        img = from_color(clamp(sp / asp + 0.5, vec2f(0.0), vec2f(1.0)));
        let facet = clamp(d.x * d.y / (0.25 * a * b + 1e-6), -1.0, 1.0);
        let rim = clamp(1.0 - dist / (0.25 * b + 1e-5), 0.0, 1.0);
        img = vec4f(img.rgb * (1.0 + params.shading * q * (0.35 * facet - 0.25 * rim)), img.a);
        if (hole <= 0.0) { return img; }
    }
    var bg = to_color(uv);
    // Soft shadow of the mesh, only within the sheet.
    let sh = (1.0 - smoothstep(0.0, 0.25 * b + e, -dist)) * clamp(0.5 + side, 0.0, 1.0);
    bg = vec4f(bg.rgb * (1.0 - 0.45 * params.shading * sh * (1.0 - q)), bg.a);
    return mix(img, bg, hole);
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
