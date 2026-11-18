// Port of MoireWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MoireWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.0012;
// Half width of a ring line, in ring spacings.
const LINE: f32 = 0.1;
// Widest antialiased edge of the bands, in bands, which also sets when they start and finish opening.
const EDGE: f32 = 0.05;
const START: f32 = 0.35;
// Strength of the ring lines at lines = 1, so the picture always shows through them.
const INK: f32 = 0.7;

// Coverage of the ring lines at radius r, box-filtered over the antialiasing width, and
// faded to their mean coverage when the rings get too fine to resolve.
fn ring_lines(r: f32, f: f32) -> f32 {
    let q = abs(fract(r * f + 0.5) - 0.5);
    let aa = AA * f;
    let c = clamp((LINE - q) / (2.0 * aa) + 0.5, 0.0, 1.0);
    return mix(c, 2.0 * LINE, clamp(10.0 * aa - 0.5, 0.0, 1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = from_color(uv);
    let b = to_color(uv);
    let t = progress * progress * (3.0 - 2.0 * progress);
    let f = max(params.density, 1.0);
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let ang = 2.0 * PI * params.drift * t + START;
    let k = max(params.bands, 1.0) * (1.0 - 0.75 * t);
    let axis = vec2f(cos(ang), sin(ang)) * 0.5 * k / f;
    let r1 = length(p - axis);
    let r2 = length(p + axis);
    // The second set is slightly finer than the first, which bends the bands into curves.
    let f2 = f + 1.2 * k;
    // The beat of the two ring sets: distance from the middle of the nearest band, in bands.
    let beat = abs(fract(f2 * r2 - f * r1 + 0.5) - 0.5);
    let grad = f2 * (p + axis) / max(r2, AA) - f * (p - axis) / max(r1, AA);
    let s = min(AA * length(grad) + 0.004, EDGE);
    let w = mix(-EDGE, 0.5 + EDGE, t);
    let m = 1.0 - smoothstep(w - s, w + s, beat);
    var c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
    let o = INK * clamp(params.lines, 0.0, 1.0) * sin(PI * t);
    let l = 1.0 - (1.0 - o * ring_lines(r1, f)) * (1.0 - o * ring_lines(r2, f2));
    c = vec4f(mix(c.rgb, vec3f(c.a * m), l), c.a);
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
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
