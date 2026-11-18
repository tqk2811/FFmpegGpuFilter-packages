// Port of ParallaxPush.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ParallaxPush.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let direction = params.direction;
    let pillar = params.pillar;
    // The main axis of the direction, to the left when there is none.
    var d = vec2f(0.0, select(-1.0, 1.0, direction.y > 0.0));
    if (abs(direction.x) >= abs(direction.y)) { d = vec2f(select(-1.0, 1.0, direction.x > 0.0), 0.0); }
    // u: position along the motion in frame heights; v: across the motion, 0 to 1.
    let len = select(1.0, ratio, d.x != 0.0);
    let u = (dot(uv - 0.5, d) + 0.5) * len;
    let v = select(uv.x, uv.y, d.x != 0.0);
    let p = progress;
    // The camera's travel: eased, with a little linear motion so it never stands still.
    let e = 0.7 * p * p * (3.0 - 2.0 * p) + 0.3 * p;
    let speed = 0.7 * 6.0 * p * (1.0 - p) + 0.3;
    // The far clips drift slowly, each scaled up just enough that its drift never shows its edges.
    let drift = clamp(params.parallax, 0.0, 0.25);
    let da = drift * e;
    let db = drift * (1.0 - e);
    let a = from_color(mirror(0.5 + (uv - 0.5) * (1.0 - 2.0 * da) - d * da));
    let b = to_color(mirror(0.5 + (uv - 0.5) * (1.0 - 2.0 * db) + d * db));
    // The pillar crosses the whole frame, out of focus and smeared by its speed.
    let w = clamp(params.width, 0.1, 1.0) * min(ratio, 1.0);
    let bl = clamp(params.blur, 0.0, 1.0);
    let defocus = w * (0.02 + 0.08 * bl);
    let smear = 0.035 * bl * (len + w);
    let soft = min(defocus + smear * speed, 0.8 * w);
    // At both ends the pillar's blurred edge just touches the frame's edge.
    let reach = 0.5 * w + 0.5 * min(defocus + smear * 0.3, 0.8 * w) + 0.001;
    let c = -reach + (len + 2.0 * reach) * e;
    // x: across the pillar, -1 on its leading edge to 1 on its trailing edge.
    let x = (c - u) / (0.5 * w);
    let edge = soft / w;
    let cover = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, abs(x));
    if (cover <= 0.0) { return select(a, b, u < c); }
    // The cut is a dissolve behind the pillar's core, so a see-through pillar never shows a seam.
    let bg = mix(a, b, smoothstep(-0.8, 0.8, x));
    let xs = clamp(x, -1.0, 1.0);
    let n = sqrt(max(1.0 - xs * xs, 0.0));
    let lambert = max(0.5 * n - 0.85 * xs, 0.0);
    let spec = pow(max(0.6 * n - 0.8 * xs, 0.0), 12.0);
    let rim = smoothstep(0.6, 1.0, abs(xs)) * (1.0 - cover);
    let side = select(b, a, xs < 0.0);
    var lit = pillar.rgb * (0.35 + 1.1 * lambert) * (0.6 + 0.5 * v) + 0.12 * spec;
    lit += 0.25 * rim * side.rgb * side.a;
    // The pillar over the clips, premultiplied.
    let pa = pillar.a * cover;
    let col = vec4f(lit * pa + bg.rgb * bg.a * (1.0 - pa), pa + bg.a * (1.0 - pa));
    return select(vec4f(0.0), vec4f(col.rgb / col.a, col.a), col.a > 0.0);
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
