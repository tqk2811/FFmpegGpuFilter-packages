// Port of Funnel.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Funnel.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const NECK: f32 = 0.04;
// How far below the bottom edge the clip's top ends, so it is gone at the end.
const OVERSHOOT: f32 = 0.03;
const EDGE: f32 = 0.0015;
const SOFT: f32 = 0.06;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress;
    let f = smoothstep(0.0, 1.0, 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t));
    let slide = (1.0 + OVERSHOOT) * t * t * (1.5 - 0.5 * t);
    let r = max(ratio, 1e-4);
    let nh = 0.5 * NECK / r;
    let tx = clamp(params.neck_x, nh, 1.0 - nh);
    let c = clamp(params.curvature, 0.0, 1.0);
    // The funnel's profile, 0 at the neck on the bottom edge to 1 at the top of the frame.
    let q = clamp(uv.y, 0.0, 1.0);
    let w = mix(q, q * q * (3.0 - 2.0 * q), c);
    let dw = mix(1.0, 6.0 * q * (1.0 - q), c);
    let L = f * mix(tx - nh, 0.0, w);
    let R = 1.0 - f * (1.0 - mix(tx + nh, 1.0, w));
    let dL = -f * (tx - nh) * dw;
    let dR = f * (1.0 - tx - nh) * dw;
    let v = uv.y + slide;
    // Antialiased coverage, measured across the slanted sides (a side on the frame's border is not an edge).
    let e = EDGE * min(1.0, 10.0 * t) + 1e-6;
    let left = select(1.0, (uv.x - L) * r / sqrt(1.0 + dL * dL * r * r), L > 0.0);
    let right = select(1.0, (R - uv.x) * r / sqrt(1.0 + dR * dR * r * r), R < 1.0);
    let cov = clamp(min(min(left, right), 1.0 - v) / e + 0.5, 0.0, 1.0);
    var img = vec4f(0.0);
    let s = clamp(params.shadow, 0.0, 1.0);
    if (cov > 0.0) {
        let width = R - L;
        let src = clamp(vec2f((uv.x - L) / width, v), vec2f(0.0), vec2f(1.0));
        img = from_color(src);
        let across = 2.0 * src.x - 1.0;
        img = vec4f(img.rgb * (1.0 - s * (1.0 - width) * (0.5 * across * across + 0.3 * (1.0 - w))), img.a);
        if (cov >= 1.0) { return img; }
    }
    var bg = to_color(uv);
    let ox = max(L - uv.x, uv.x - R) * r;
    let oy = uv.y - (1.0 - slide);
    let dist = length(max(vec2f(ox, oy), vec2f(0.0)));
    bg = vec4f(bg.rgb * (1.0 - s * 0.6 * f * (1.0 - t) * (1.0 - smoothstep(0.0, SOFT, dist))), bg.a);
    return mix(bg, img, cov);
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
