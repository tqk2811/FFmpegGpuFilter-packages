// Port of KeyholeWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/KeyholeWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The keyhole, in its own units (0.85 tall, from y = -0.4 to 0.45): a round head on top of a
// slot that widens downward.
const HEAD: vec2f = vec2f(0.0, 0.2);
const HEAD_R: f32 = 0.25;
const SLOT_Y: f32 = -0.17;
const SLOT_HE: f32 = 0.23;
const SLOT_TOP: f32 = 0.085;
const SLOT_BOTTOM: f32 = 0.165;
const SLOT_ROUND: f32 = 0.025;
// Height of the point the keyhole grows around, in its head.
const GROW_Y: f32 = 0.1;
const BEVEL: f32 = 0.028;
const SHADE: f32 = 0.05;

fn dot2(v: vec2f) -> f32 { return dot(v, v); }

fn sd_slot(p_in: vec2f) -> f32 {
    var p = p_in;
    p.y -= SLOT_Y;
    let r1 = SLOT_BOTTOM - SLOT_ROUND;
    let r2 = SLOT_TOP - SLOT_ROUND;
    let he = SLOT_HE - SLOT_ROUND;
    let k1 = vec2f(r2, he);
    let k2 = vec2f(r2 - r1, 2.0 * he);
    p.x = abs(p.x);
    let ca = vec2f(p.x - min(p.x, select(r2, r1, p.y < 0.0)), abs(p.y) - he);
    let cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot2(k2), 0.0, 1.0);
    let s = select(1.0, -1.0, cb.x < 0.0 && ca.y < 0.0);
    return s * sqrt(min(dot2(ca), dot2(cb))) - SLOT_ROUND;
}

fn sd_keyhole(p: vec2f) -> f32 { return min(length(p - HEAD) - HEAD_R, sd_slot(p)); }

// Scale at which the head, a disk, reaches the point p (seen from the growth point).
fn reach(p: vec2f) -> f32 {
    let h = HEAD - vec2f(0.0, GROW_Y);
    let k = HEAD_R * HEAD_R - dot2(h);
    let b = dot(p, h);
    return (sqrt(b * b + k * dot2(p)) - b) / k;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var a = from_color(uv);
    var b = to_color(uv);
    let asp = vec2f(ratio, 1.0);
    // `center` is given y down.
    let o = vec2f(params.center.x, 1.0 - params.center.y) * asp;
    let sm = max(params.smoothness, 0.0005);
    // It covers the frame once its head reaches the corners (grown by a margin).
    let lo = -o - 2.5 * sm;
    let hi = asp - o + 2.5 * sm;
    let full = max(max(reach(lo), reach(hi)), max(reach(vec2f(lo.x, hi.y)), reach(vec2f(hi.x, lo.y))));
    let p = progress;
    let s = full * p;
    if (s <= 0.0) { return a; }
    let q = (uv * asp - o) / s + vec2f(0.0, GROW_Y);
    let d = sd_keyhole(q);
    // The soft edge is just inside the outline, so a tiny keyhole shows nothing.
    let hole = 1.0 - smoothstep(-sm, sm, d * s + sm);
    let fade = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.7, 1.0, p));
    let rim_a = params.rim * fade;
    if (rim_a > 0.0) {
        let e = vec2f(0.002, 0.0);
        let n = vec2f(sd_keyhole(q + e) - sd_keyhole(q - e), sd_keyhole(q + e.yx) - sd_keyhole(q - e.yx));
        let lit = -dot(n / max(length(n), 1e-6), vec2f(-0.35, 0.94));
        let bevel = 1.0 - smoothstep(0.0, BEVEL, d);
        let shade = exp(-max(d, 0.0) / SHADE);
        var rgb = a.rgb * (1.0 - rim_a * (0.35 * shade + bevel * 0.4 * max(-lit, 0.0)));
        rgb += rim_a * bevel * bevel * 0.3 * max(lit, 0.0) * a.a;
        a = vec4f(rgb, a.a);
        let wall = smoothstep(-0.03, 0.03, sd_keyhole(q + vec2f(0.0, 0.05)));
        let vign = exp(min(d, 0.0) / SHADE);
        b = vec4f(b.rgb * (1.0 - rim_a * (0.5 * wall + 0.3 * vign)), b.a);
    }
    return mix(a, b, hole);
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
