// Port of HeartWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HeartWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture. `center` is given y down, as the
// other gpufx packages, and flipped here.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The heart: tip at (0, 0), notch at (0, 1), lobes are circles of radius sqrt(2)/4 centered at
// (+-0.25, 0.75), tangent to the lines y = |x|. HEART_O is its center.
const HEART_O: vec2f = vec2f(0.0, 0.55);
const LOBE: vec2f = vec2f(0.25, 0.75);
const LOBE_R: f32 = 0.35355339;

fn dot2(v: vec2f) -> f32 { return dot(v, v); }

fn sd_heart(p_in: vec2f) -> f32 {
    let p = vec2f(abs(p_in.x), p_in.y);
    if (p.x + p.y > 1.0) { return sqrt(dot2(p - LOBE)) - LOBE_R; }
    return sqrt(min(dot2(p - vec2f(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

// Scale of the smallest heart (centered on HEART_O) that contains p: the heart is the union of a
// lobe disk and the triangle |x| <= y, |x| + y <= 1, both convex around HEART_O, so the boundary
// along a ray is the farthest of their exits.
fn heart_scale(p: vec2f) -> f32 {
    let l = length(p);
    if (l < 1e-6) { return 0.0; }
    let d = vec2f(abs(p.x), p.y) / l;
    let m = HEART_O - LOBE;
    let b = dot(m, d);
    let t_disk = -b + sqrt(b * b - dot2(m) + LOBE_R * LOBE_R);
    let t_side = select(1e6, HEART_O.y / (d.x - d.y), d.x > d.y);
    let t_top = select(1e6, (1.0 - HEART_O.y) / (d.x + d.y), d.x + d.y > 0.0);
    return l / max(t_disk, min(t_side, t_top));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let a = from_color(uv);
    let b = to_color(uv);
    let ratio = globals.size.x / globals.size.y;
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let asp = vec2f(ratio, 1.0);
    let c = center * asp;
    // Scale at which the heart covers the whole frame: the corners, plus the point of the top
    // edge in line with the notch (the only concave part of the heart).
    let cx = clamp(center.x, 0.0, 1.0) * ratio;
    var full = max(
        max(max(heart_scale(vec2f(0.0, 0.0) - c), heart_scale(vec2f(ratio, 0.0) - c)),
            max(heart_scale(vec2f(0.0, 1.0) - c), heart_scale(vec2f(ratio, 1.0) - c))),
        heart_scale(vec2f(cx, 1.0) - c));
    let sm = max(params.smoothness, 0.001);
    // Margin so the soft edge is past the frame at progress = 1.
    full += 4.0 * sm;

    let p = progress;
    let e = p * p * (2.0 - p);
    let env = max(sin(3.14159265 * p), 0.0);
    let beat = sin(6.28318531 * 2.0 * p) * env * env;
    let s = full * clamp(e + 0.09 * params.pulse * beat, 0.0, 1.0);
    if (s <= 0.0) { return a; }

    let q = uv * asp - c;
    let d = s * sd_heart(q / s + HEART_O);
    let m = smoothstep(0.0, sm, -d);
    let col = mix(a, b, m);
    // Soft light just outside the edge, faded in and out with the transition (adds no alpha).
    let light = exp(-max(d, 0.0) / (0.008 + sm)) * (1.0 - m) * params.glow * min(1.0, 4.0 * env);
    return col + vec4f(params.glow_color.rgb * light, 0.0);
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
