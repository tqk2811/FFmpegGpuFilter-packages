// Port of Prisms.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Prisms.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.002;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let horizontal = params.horizontal != 0u;
    let n = f32(max(params.slats, 2));
    let stagger = params.stagger;
    // a: the axis across the prisms, b: the axis they turn around.
    let a = select(uv.x, uv.y, horizontal);
    let b = select(uv.y, uv.x, horizontal);
    let hw = 0.5 / n * select(ratio, 1.0, horizontal);
    let k = min(params.perspective * hw, 0.5);
    let b_scale = select(1.0, ratio, horizontal);
    // A turning prism is wider than its strip: keep the two nearest faces.
    var near1 = vec4f(0.0);
    var near2 = vec4f(0.0);
    var cover1 = 0.0;
    var cover2 = 0.0;
    var z1 = -2.0;
    var z2 = -2.0;
    for (var dd = -1; dd <= 1; dd++) {
        let i = floor(a * n) + f32(dd);
        if (i < 0.0 || i > n - 1.0) { continue; }
        let order = select(i, n - 1.0 - i, horizontal) / (n - 1.0);
        var t = clamp((progress - stagger * order) / (1.0 - stagger), 0.0, 1.0);
        t = mix(t, t * t * (3.0 - 2.0 * t), 0.7);
        let c = cos(0.5 * PI * t);
        let s = sin(0.5 * PI * t);
        // Soft edges while turning (sharp at rest).
        let edge = EDGE * min(1.0, 20.0 * s * c) + 1e-6;
        let x = 2.0 * (a * n - i) - 1.0;
        for (var f = 0; f < 2; f++) {
            // f = 0: the outgoing face turning away, f = 1: the incoming face turning in.
            let cf = select(s, c, f == 0);
            if (cf < 1e-4) { continue; }
            let u = select((x - c) / s, (x + s) / c, f == 0);
            let z = select(s - u * c, u * s + c, f == 0);
            if (abs(u) > 1.0 || z <= z2) { continue; }
            let scale = 1.0 - k * (z - 1.0);
            let y = (b - 0.5) * scale + 0.5;
            if (y < 0.0 || y > 1.0) { continue; }
            // Soften the outer edges only: the faces meet at the prism corner.
            let outer = select(1.0 - u, 1.0 + u, f == 0);
            let cover = clamp(outer * hw * cf / edge, 0.0, 1.0) * clamp(min(y, 1.0 - y) * b_scale / scale / edge, 0.0, 1.0);
            let sa = (i + 0.5 + 0.5 * u) / n;
            let pt = select(vec2f(sa, y), vec2f(y, sa), horizontal);
            let img = select(to_color(pt), from_color(pt), f == 0);
            let lambert = clamp(select(s + 0.6 * c, c - 0.6 * s, f == 0), 0.0, 1.0);
            let color = vec4f(img.rgb * mix(1.0 - params.shading, 1.0, lambert), img.a);
            if (z > z1) {
                near2 = near1; cover2 = cover1; z2 = z1;
                near1 = color; cover1 = cover; z1 = z;
            } else {
                near2 = color; cover2 = cover; z2 = z;
            }
        }
    }
    return mix(mix(params.back_color, near2, cover2), near1, cover1);
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
