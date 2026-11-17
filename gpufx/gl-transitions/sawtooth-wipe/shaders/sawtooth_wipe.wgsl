// Port of SawtoothWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SawtoothWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;

// Signed distance to a zigzag line of period w and peak-to-peak height h, centered on y = 0,
// its tips pointing up at x = 0; positive above it.
fn zigzag(q: vec2f, w: f32, h: f32) -> f32 {
    // Fold into half a tooth: the slope from the bottom of a notch to the tip of a tooth.
    let x = abs(fract(q.x / w) - 0.5) * w;
    let a = vec2f(0.0, -0.5 * h);
    let ab = vec2f(0.5 * w, h);
    let aq = vec2f(x, q.y) - a;
    let d = length(aq - ab * clamp(dot(aq, ab) / dot(ab, ab), 0.0, 1.0));
    return select(-d, d, q.y > h * (2.0 * x / w - 0.5));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = from_color(uv);
    let b = to_color(uv);
    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    // Measured in square pixels, so the teeth are not stretched.
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let w = 0.5 * (abs(dir.y) * ratio + abs(dir.x));
    let period = 2.0 * w / f32(max(params.teeth, 1));
    // Position across the edge, with notches on the sides of the frame so it shows whole teeth, and along the direction.
    let q = vec2f(dot(p, vec2f(-dir.y, dir.x)) + w + 0.5 * period, dot(p, dir));
    let h = max(params.depth, 0.0) * period;
    // The soft edge never gets wide enough to blur small teeth away.
    let s = max(min(params.smoothness, 0.25 * period), AA);
    let t = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.35);
    var d: f32;
    if (params.jaws != 0u) {
        // The two edges are the same zigzag, interlocked at the start, then moving apart
        // until each one has left the frame on its side.
        let overlap = s * sqrt(1.0 + 4.0 * h * h / (period * period));
        let o = mix(-overlap, e + 0.5 * h + s, t);
        d = max(zigzag(q - vec2f(0.0, o), period, h), -zigzag(q + vec2f(0.0, o), period, h));
    } else {
        // The edge starts fully ahead of the frame and ends fully past it.
        let c = mix(-e - 0.5 * h - s, e + 0.5 * h + s, t);
        d = zigzag(q - vec2f(0.0, c), period, h);
    }
    let m = 1.0 - smoothstep(-s, s, d);
    let c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
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
