// Port of ColorPanelWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ColorPanelWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The frame is fully covered from CUT - HOLD to CUT + HOLD, where the clips switch.
const CUT: f32 = 0.46;
const HOLD: f32 = 0.01;
const AA: f32 = 0.0015;

fn ease(t: f32) -> f32 {
    let s = clamp(t, 0.0, 1.0);
    let u = 1.0 - s * s * (3.0 - 2.0 * s);
    return 1.0 - u * u * u;
}

fn cover(x: f32, back: f32, front: f32) -> f32 {
    return smoothstep(back - AA, back + AA, x) * (1.0 - smoothstep(front - AA, front + AA, x));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let k = clamp(params.skew, -1.0, 1.0);
    let a = (dir + k * vec2f(-dir.y, dir.x)) / sqrt(1.0 + k * k);
    let x = dot(p, a);
    let e = 0.5 * (abs(a.x) * ratio + abs(a.y));
    let start = -e - 2.0 * AA;
    let span = 2.0 * (e + 2.0 * AA);

    let n = clamp(params.panels, 1, 3);
    let m = f32(n - 1);
    let st = clamp(params.stagger, 0.0, 1.0);
    let d = vec2f(CUT - HOLD, 1.0 - CUT - HOLD) / (1.0 + m * st);

    // The first panel enters first and leaves last; both clips are sampled so no texture read
    // sits in a divergent branch.
    let front0 = start + span * ease(progress / d.x);
    let back0 = start + span * ease((progress - 1.0 + d.y) / d.y);
    var c = mix(to_color(uv), from_color(uv), step(0.5 * (front0 + back0), x));
    c = mix(c, params.color1, cover(x, back0, front0));

    for (var i = 1; i < 3; i++) {
        if (i < n) {
            let t = f32(i) * st * d;
            let front = start + span * ease((progress - t.x) / d.x);
            let back = start + span * ease((progress - 1.0 + d.y + t.y) / d.y);
            c = mix(c, select(params.color3, params.color2, i == 1), cover(x, back, front));
        }
    }
    if (c.a > 0.0) { return c; }
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
