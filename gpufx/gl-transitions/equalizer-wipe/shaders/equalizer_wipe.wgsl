// Port of EqualizerWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EqualizerWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.0015;
const CAP: f32 = 0.012;
const CAP_GAP: f32 = 0.008;

fn hash11(n_in: f32) -> f32 {
    var n = fract(n_in * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

// Level of bar i (0 at the bottom of the frame, 1 at the top) at progress t: an eased average
// level climbing from below the frame to above it, plus a bounce that is zero at both ends.
fn level(i: f32, k: vec4f, lead: f32, t_in: f32, amp: f32) -> f32 {
    let t = clamp(t_in, 0.0, 1.0);
    let env = sin(PI * t);
    let ramp = t * t * (3.0 - 2.0 * t);
    let base = mix(-0.03, 1.04, mix(t, ramp, 0.3));
    let w = 2.0 * PI * t;
    let osc = 0.5 * sin(w * k.x + k.y) + 0.3 * sin(w * k.z + k.w) + 0.2 * sin(w * 2.2 - 0.55 * i);
    return base + amp * env * (osc + lead);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = f32(max(params.bars, 1));
    let amp = max(params.bounce, 0.0);
    let x = uv.x * n;
    let i = min(floor(x), n - 1.0);
    let fx = x - i;
    let aa_x = AA * n / ratio;
    let k = vec4f(3.0 + 1.5 * hash11(i + 3.0), 2.0 * PI * hash11(i),
                  5.5 + 2.0 * hash11(i + 7.0), 2.0 * PI * hash11(i + 11.0));
    let lead = 0.35 * (hash11(i + 19.0) - 0.5);
    let h = level(i, k, lead, progress, amp);
    // The peak cap: the highest recent level, held a moment then falling back faster and faster.
    var peak = h;
    for (var j = 1; j < 12; j++) {
        let dt = f32(j) * 0.012;
        let fall = max(dt - 0.03, 0.0);
        peak = max(peak, level(i, k, lead, progress - dt, amp) - 60.0 * fall * fall);
    }
    let cap_y = peak + CAP_GAP;
    // A gap thinner than the antialiasing fades out instead of blurring the sides of the bar.
    let open = 1.0 - smoothstep(0.72, 0.97, progress);
    let gap = 0.09 * open;
    let side = min(fx, 1.0 - fx);
    let in_gap = clamp((gap - side) / (2.0 * aa_x) + 0.5, 0.0, 1.0) * min(gap / aa_x, 1.0);
    let bar_x = 1.0 - in_gap;
    var b = to_color(uv);
    var fill: f32;
    var lit: f32;
    if (params.segments > 0) {
        let segs = f32(params.segments);
        let above = h * segs - floor(uv.y * segs);
        fill = clamp(above, 0.0, 1.0);
        lit = 1.0 - clamp(above - 1.0, 0.0, 1.0);
        let seam = abs(fract(uv.y * segs) - 0.5) * 2.0;
        let aa_s = AA * segs * 2.0;
        b = vec4f(b.rgb * (1.0 - 0.38 * open * smoothstep(0.78 - aa_s, 0.78 + aa_s, seam)), b.a);
    } else {
        fill = 1.0 - smoothstep(h - AA, h + AA, uv.y);
        lit = 1.0 - smoothstep(0.0, 0.04, h - uv.y);
    }
    var rgb = b.rgb + 0.2 * open * lit * (1.0 - b.rgb);
    let across = 2.0 * fx - 1.0;
    rgb *= 1.0 - 0.15 * open * across * across;
    b = vec4f(rgb, b.a);
    let m = bar_x * fill;
    var a = from_color(uv);
    let beside = (1.0 - smoothstep(0.0, gap, gap - side)) * (1.0 - smoothstep(h - 0.01, h + 0.01, uv.y));
    let under = bar_x * smoothstep(cap_y - 0.025, cap_y, uv.y) * (1.0 - smoothstep(cap_y - AA, cap_y + AA, uv.y));
    a = vec4f(a.rgb * (1.0 - open * (0.35 * in_gap * beside + 0.4 * under)), a.a);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    var c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
    var cap = bar_x * smoothstep(cap_y - AA, cap_y + AA, uv.y) * (1.0 - smoothstep(cap_y + CAP - AA, cap_y + CAP + AA, uv.y));
    cap *= params.cap_color.a * smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.95, 1.0, progress));
    c = mix(c, vec4f(params.cap_color.rgb, 1.0), cap);
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
