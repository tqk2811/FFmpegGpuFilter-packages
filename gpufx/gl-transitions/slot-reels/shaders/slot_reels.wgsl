// Port of SlotReels.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SlotReels.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// Half of the arc of the drum seen in the frame, in radians.
const ARC: f32 = 1.15;
const SETTLE: f32 = 0.1;
const LINE: f32 = 0.006;
const EDGE: f32 = 0.0015;

fn stop_time(i: f32, n: f32) -> f32 {
    var order = 1.0;
    if (n > 1.0) { order = i / (n - 1.0); }
    return (1.0 - SETTLE) * (1.0 - clamp(params.stagger, 0.0, 0.9) * (1.0 - order));
}

// How far the reel has turned at time t, in picture heights: it speeds up, slows down to its stop
// a little past the second clip and springs back onto it.
fn reel_offset(t: f32, stop_t: f32, turns: f32) -> f32 {
    let amp = 0.07 * params.bounce;
    // Speed at the stop, matched with the start of the bounce.
    let v1 = amp * PI * stop_t / (turns * SETTLE);
    let u = clamp(t / stop_t, 0.0, 1.0);
    let g = u * u * (3.0 - 2.0 * u) + v1 * (u * u * u - u * u);
    let b = clamp((t - stop_t) / SETTLE, 0.0, 1.0);
    return turns * g + amp * sin(PI * b) * (1.0 - b) * (1.0 - b);
}

// The reel's speed at time t, the derivative of reel_offset.
fn reel_speed(t: f32, stop_t: f32, turns: f32) -> f32 {
    let amp = 0.07 * params.bounce;
    let v1 = amp * PI * stop_t / (turns * SETTLE);
    if (t < stop_t) {
        let u = max(t / stop_t, 0.0);
        return turns * (6.0 * u * (1.0 - u) + v1 * u * (3.0 * u - 2.0)) / stop_t;
    }
    let b = min((t - stop_t) / SETTLE, 1.0);
    return amp * (1.0 - b) * (PI * cos(PI * b) * (1.0 - b) - 2.0 * sin(PI * b)) / SETTLE;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = max(f32(params.reels), 1.0);
    let i = min(floor(uv.x * n), n - 1.0);
    let lx = uv.x * n - i;
    let stop_t = stop_time(i, n);
    // An odd number of turns, more for the reels that spin longer, so they land on the second clip.
    let turns = 2.0 * floor(stop_t * 4.0) + 1.0;

    let drum = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(stop_t, stop_t + SETTLE, progress));
    let y = 2.0 * uv.y - 1.0;
    // theta: the angle around the drum's axis, 0 facing the viewer.
    let theta = asin(clamp(y * sin(ARC), -1.0, 1.0));
    let v = mix(uv.y, 0.5 + theta / (2.0 * ARC), drum);
    let depth = (1.0 - cos(theta)) * drum;
    let px = 0.5 + (lx - 0.5) * (1.0 + 0.2 * depth);

    // Offset from the resting position, -turns at the start, 0 once landed.
    let off = reel_offset(progress, stop_t, turns) - turns;
    let speed = abs(reel_speed(progress, stop_t, turns));
    let spread = params.blur * min(speed * 0.02, 0.22) * drum;

    var c = vec4f(0.0);
    var wsum = 0.0;
    for (var k = 0; k < 8; k++) {
        let f = f32(k) / 7.0 - 0.5;
        let w = 1.0 - abs(f);
        let vv = v + off + spread * f;
        let seg = floor(vv);
        let q = vec2f((i + clamp(px, 0.0, 1.0)) / n, vv - seg);
        var s: vec4f;
        if (seg - 2.0 * floor(seg / 2.0) < 0.5) { s = to_color(q); } else { s = from_color(q); }
        // A thin shadow at the seams between the pictures, not at the frame's top and bottom edges.
        s = vec4f(s.rgb * (1.0 - 0.6 * drum * (1.0 - y * y) * (1.0 - smoothstep(0.0, 0.02, min(q.y, 1.0 - q.y)))), s.a);
        c += w * s;
        wsum += w;
        if (spread < 1e-4) { break; }
    }
    c /= wsum;

    let facing = cos(theta);
    var rgb = c.rgb * mix(1.0, 0.25 + 0.75 * facing * facing, drum);
    rgb += drum * 0.07 * c.a * exp(-12.0 * (y - 0.3) * (y - 0.3));

    let env = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
    let reel_w = ratio / n;
    let persp = reel_w / (1.0 + 0.2 * depth);
    let d_side = min(px, 1.0 - px) * persp;
    let d_inner = min(select(2.0, px, i > 0.5), select(2.0, 1.0 - px, i < n - 1.5)) * persp;
    let line = 1.0 - smoothstep(0.5 * LINE - EDGE, 0.5 * LINE + EDGE, d_inner);
    let outside = 1.0 - smoothstep(-EDGE, 0.0, d_side);
    rgb *= 1.0 - 0.35 * env * (1.0 - smoothstep(0.0, 0.03 * reel_w + LINE, d_inner));
    return mix(vec4f(rgb, c.a), params.separator, max(line * env, outside));
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
