// Port of GlassRelief.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlassRelief.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 24;
// In frame heights: wide enough that fine texture averages out of the height field.
const RADIUS: f32 = 0.05;

fn luma(c: vec4f) -> f32 {
    return dot(c.rgb, vec3f(0.299, 0.587, 0.114)) * c.a + 0.3 * (1.0 - c.a);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let refraction = params.refraction;
    let shine = params.shine;
    let rise = smoothstep(0.0, 0.4, progress);
    let melt = smoothstep(0.35, 1.0, progress);
    let relief = rise * (1.0 - melt);
    // Gaussian-weighted plane fit of the incoming brightness over a golden-angle spiral.
    let turn = mat2x2f(-0.73736, 0.67549, -0.67549, -0.73736);
    var dir = vec2f(1.0, 0.0);
    var sw = 0.0;
    var sl = 0.0;
    var sdd = 0.0;
    var sd = vec2f(0.0);
    var sld = vec2f(0.0);
    for (var i = 0; i < TAPS; i++) {
        let f = (f32(i) + 0.5) / f32(TAPS);
        let d = RADIUS * sqrt(f) * dir;
        let w = exp(-4.0 * f);
        let l = luma(to_color(mirror(uv + vec2f(d.x / ratio, d.y))));
        sw += w;
        sl += w * l;
        sd += w * d;
        sld += w * l * d;
        sdd += w * dot(d, d);
        dir = turn * dir;
    }
    let h = sl / sw;
    var g = 0.08 * (sld - h * sd) / (sdd - dot(sd, sd) / sw);
    // Steep slopes are rounded off so the glass stays smooth on strong edges.
    g /= 1.0 + 1.5 * length(g);
    let off = -g * 0.2 * refraction * relief / vec2f(ratio, 1.0);
    var behind = from_color(mirror(uv + off));
    let fringe = 0.08 * refraction * relief;
    let cr = from_color(mirror(uv + off * (1.0 + fringe)));
    let cb = from_color(mirror(uv + off * (1.0 - fringe)));
    behind.r = mix(behind.r, cr.r, cr.a);
    behind.b = mix(behind.b, cb.b, cb.a);
    let n = normalize(vec3f(-g * 4.0 * relief, 1.0));
    // The light swings over the transition, so the glints slide along the outlines.
    let a = 2.0 * (progress - 0.4);
    let ld = mat2x2f(cos(a), sin(a), -sin(a), cos(a)) * params.light;
    let lt = normalize(vec3f(ld, 0.9));
    let diff = dot(n, lt) - lt.z;
    let spec = pow(max(dot(reflect(-lt, n), vec3f(0.0, 0.0, 1.0)), 0.0), 40.0);
    let rim = 1.0 - n.z;
    let glass = behind.rgb * (1.0 + 0.6 * shine * diff) + shine * (0.9 * spec * relief * min(length(g) * 6.0, 1.0) + 0.4 * max(diff, 0.0) + 0.4 * rim);
    let to = to_color(uv);
    let lag = 0.7 * (1.0 - clamp(mix(h, luma(to), 0.3), 0.0, 1.0));
    let fill = smoothstep(lag, lag + 0.3, melt);
    return vec4f(clamp(mix(glass, to.rgb, fill), vec3f(0.0), vec3f(1.0)), mix(behind.a, to.a, fill));
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
