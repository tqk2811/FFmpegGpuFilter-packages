// Port of PopIn.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PopIn.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn rounded_box(p: vec2f, b: vec2f, r: f32) -> f32 {
    let q = abs(p) - b + r;
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // The center option is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let t = progress;
    // An ease-out plus a damped spring that overshoots and lands exactly at t = 1.
    let ease_out = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
    let spring = 1.0 - exp(-1.5 * t) * cos(2.5 * PI * t) * (1.0 - t);
    let s = mix(ease_out, spring, params.bounce);
    let asp = vec2f(ratio, 1.0);
    let side = min(ratio, 1.0);
    let card_center = center + (0.5 - center) * s;
    let half_size = 0.5 * s * asp;
    let r = params.corner * s * side * (1.0 - t);
    let aa = 0.002;
    // The edge is pushed out by one antialiasing width, so at t = 1 the card covers the whole frame.
    let d = rounded_box((uv - card_center) * asp, half_size, r) - aa;
    let cover = clamp(0.5 - d / aa, 0.0, 1.0) * smoothstep(0.0, 0.08, t);
    let k = min(s, 1.0) * side;
    let blur = 0.05 * k + 1e-4;
    let offset = vec2f(0.0, -0.03 * k);
    let ds = rounded_box((uv - card_center - offset) * asp, half_size, r);
    let shade = params.shadow * (1.0 - smoothstep(-blur, blur, ds)) * smoothstep(0.0, 0.15, t);
    var a = from_color(uv);
    // The shadow darkens the first clip without changing its alpha.
    a = vec4f(a.rgb * (1.0 - shade), a.a);
    let b = to_color(clamp((uv - center) / max(s, 1e-4) + center, vec2f(0.0), vec2f(1.0)));
    let c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), cover);
    return select(vec4f(0.0), vec4f(c.rgb / c.a, c.a), c.a > 0.0);
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
