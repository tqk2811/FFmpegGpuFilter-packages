// Port of ArrowWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ArrowWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Signed distance (in frame heights) to an arrowhead whose tip is at x = tip and whose notch
// reaches back to x = back, in the arrow's frame (x along the direction, y = |across|).
fn arrow(q: vec2f, tip: f32, back: f32, tip_n: vec2f, notch_n: vec2f) -> f32 {
    let front = dot(vec2f(q.x - tip, q.y), tip_n);
    let rear = dot(vec2f(back - q.x, -q.y), notch_n);
    return max(front, rear);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let across = vec2f(-dir.y, dir.x);
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let q = vec2f(dot(p, dir), abs(dot(p, across)));

    let s = max(params.smoothness, 0.001);
    let n = clamp(params.notch, 0.0, 0.9);
    let h = radians(0.5 * clamp(params.width, 20.0, 160.0));
    let cot = cos(h) / sin(h);
    let tip_n = vec2f(sin(h), cos(h));
    let notch_len = length(vec2f(1.0, n * cot));
    let notch_n = vec2f(1.0, n * cot) / notch_len;
    // How far the tip must pass a point for the soft edge to clear it.
    let tip_pad = s / sin(h);

    let c1 = vec2f(0.5 * ratio, 0.5);
    let c2 = vec2f(0.5 * ratio, -0.5);
    let k1 = vec2f(abs(dot(c1, dir)), abs(dot(c1, across)));
    let k2 = vec2f(abs(dot(c2, dir)), abs(dot(c2, across)));
    let e = max(k1.x, k2.x);
    let r = 0.5 / max(abs(dir.x) / ratio, abs(dir.y));
    // To cover the frame, the tip must be ahead of every corner, and the notch behind every
    // corner and behind the back edge's middle (with room for the soft edge).
    let tip_min = max(k1.x + k1.y * cot, k2.x + k2.y * cot) + tip_pad;
    let notch_max = min(min(n * cot * k1.y - k1.x, n * cot * k2.y - k2.x), -r) - s * notch_len;

    // The arrow (length 1 from tip to barbs) turns around the middle of its axis.
    let body = 0.5 * (1.0 - n);
    // The scale at which the arrow centered on the frame covers it.
    let cover = max(tip_min, -notch_max) / body;

    let t = progress;
    var o: f32; // middle of the arrow
    var l: f32; // size of the arrow
    if (params.origin != 0u) {
        o = 0.0;
        l = cover * t * (0.4 + 0.6 * t);
    } else {
        let l0 = 0.92 * min(1.0, ratio) / max(1.0, 2.0 * tan(h));
        let o0 = -e - 2.0 * tip_pad - body * l0;
        let u = 1.0 - clamp(t / 0.65, 0.0, 1.0);
        let fly = 1.0 - u * u * u;
        // The swell speeds up and still moves at the end, so the last corners do not linger.
        let grow = clamp((t - 0.3) / 0.7, 0.0, 1.0);
        o = mix(o0, 0.0, fly);
        l = mix(l0, cover, grow * grow * (2.0 - grow));
    }

    let gap = (1.0 - n) * 1.35;
    var d = arrow(q, o + body * l, o - body * l, tip_n, notch_n);
    for (var i = 1; i < 3; i++) {
        if (i < params.count) {
            let back = o - f32(i) * gap * l;
            d = min(d, arrow(q, back + body * l, back - body * l, tip_n, notch_n));
        }
    }
    // The soft edge slides from outside the arrow to inside it, so nothing shows at the start.
    let m = 1.0 - smoothstep(-s, s, d + 2.0 * s * (1.0 - t));

    let a = from_color(uv);
    let b = to_color(uv);
    // Mixed premultiplied, so transparent clips do not bleed their color.
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
