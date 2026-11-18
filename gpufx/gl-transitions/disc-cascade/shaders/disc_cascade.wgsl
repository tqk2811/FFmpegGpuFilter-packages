// Port of DiscCascade.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DiscCascade.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;
// Each turn lasts this many beats, so the next size starts before the previous one stops.
const D: f32 = 1.5;

fn ease3(x0: f32) -> f32 {
    let x = clamp(x0, 0.0, 1.0);
    let y = 2.0 - 2.0 * x;
    return select(1.0 - 0.5 * y * y * y, 4.0 * x * x * x, x < 0.5);
}

fn bump(x: f32) -> f32 { return sin(PI * clamp(x, 0.0, 1.0)); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let nn = clamp(f32(params.levels), 2.0, 4.0);
    let q = progress * (2.0 * nn - 1.0 + D);
    let asp = vec2f(ratio, 1.0);
    var p = uv;
    var lit = 1.0;
    var n = 8.0;
    for (var i = 3; i >= 0; i--) {
        let k = f32(i);
        if (k >= nn) {
            n *= 0.5;
            continue;
        }
        var a: f32;
        var m: f32;
        if (k == nn - 1.0) {
            let t = (q - k) / (1.0 + D);
            // fract brings the finished full turn back to exactly 0, sin(2 PI) is not 0 in floats.
            a = 2.0 * PI * fract(ease3(t));
            m = bump(t);
        } else {
            let t0 = (q - k) / D;
            let t1 = (q - (2.0 * nn - 1.0 - k)) / D;
            a = PI * (ease3(t0) - ease3(t1));
            m = bump(t0) + bump(t1);
        }
        m = clamp(m, 0.0, 1.0);
        a *= select(-1.0, 1.0, k - 2.0 * floor(k / 2.0) < 0.5);
        let cc = (floor(p * n) + 0.5) / n;
        let d = (p - cc) * asp;
        let r = 0.5 * min(ratio, 1.0) / n;
        let l = length(d);
        let aa = 0.002;
        let seam = 1.0 - smoothstep(0.0, aa, abs(l - r));
        lit *= 1.0 - seam * (0.2 * abs(sin(a * 0.5)) + 0.35 * m);
        // The shadow only falls in this disc's cell, so it fades out before the cell border.
        let cell = 0.5 * asp / n - abs(d);
        let ls = length(d - vec2f(0.4, -0.6) * 0.06 * r);
        lit *= 1.0 - params.shadow * 0.6 * m * smoothstep(r - aa, r, l) * (1.0 - smoothstep(r * 0.85, r * 1.12, ls)) * smoothstep(0.0, 0.1 * r, min(cell.x, cell.y));
        if (l < r) {
            // The turn eases to 0 over the last pixels of the rim, which antialiases the cut.
            let b = a * (1.0 - smoothstep(r - aa, r, l));
            let c = cos(b);
            let s = sin(b);
            p += (mat2x2f(c, s, -s, c) * d - d) / asp;
            lit *= 1.0 + 0.12 * m * smoothstep(r * 0.8, r, l) * dot(normalize(d + 1e-6), vec2f(-0.6, 0.8));
        }
        n *= 0.5;
    }
    let x = smoothstep(nn - 0.9, nn + D - 0.1, q);
    let col = mix(from_color(p), to_color(p), x);
    return vec4f(col.rgb * lit, col.a);
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
