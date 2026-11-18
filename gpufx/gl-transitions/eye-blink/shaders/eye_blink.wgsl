// Port of EyeBlink.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EyeBlink.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 16;
// How much the eyelids curve: the opening is widest at the center.
const CURVE: f32 = 0.25;
// Where the eyelids meet, below the middle.
const MEET: f32 = 0.44;

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

// A blink fully closed at c (held for 2 * hold): the lids close over wc before it and open
// over wo after it.
fn lid_blink(t: f32, c: f32, wc: f32, wo: f32, hold: f32) -> f32 {
    return 1.0 - smoothstep(hold, select(wo, wc, t < c), abs(t - c));
}

fn image(uv: vec2f, incoming: bool) -> vec4f {
    let c = select(from_color(uv), to_color(uv), incoming);
    return vec4f(c.rgb * c.a, c.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let two = params.blinks > 1;
    let cut = select(0.42, 0.3, two);
    var closed = lid_blink(progress, cut, 0.36, 0.5, 0.02);
    if (two) { closed = max(lid_blink(progress, cut, 0.26, 0.26, 0.015), lid_blink(progress, 0.7, 0.14, 0.24, 0.01)); }
    let incoming = progress >= cut;
    let soft = clamp(params.softness, 0.001, 0.3);
    let x = 2.0 * uv.x - 1.0;
    let rim = (1.0 - closed) * (1.31 + CURVE) - CURVE * x * x;
    let y = uv.y - MEET;
    let d = rim - max(y / (1.0 - MEET), -y / MEET);
    let s = 1.0 - smoothstep(0.0, soft, d);
    let lid = s * s;
    if (lid >= 1.0) { return params.color; }
    var f = select((1.0 - progress) / (1.0 - cut), progress / cut, progress < cut);
    f = clamp(f, 0.0, 1.0);
    f = max(f * (2.0 - f), closed) * params.blur;
    var c: vec4f;
    if (f <= 0.0) {
        c = select(from_color(uv), to_color(uv), incoming);
    } else {
        let r = 0.025 * f;
        c = vec4f(0.0);
        for (var i = 0; i < TAPS; i++) {
            let k = f32(i) + 0.5;
            let a = 2.39996 * k;
            let o = sqrt(k / f32(TAPS)) * vec2f(cos(a), sin(a)) * r;
            c += image(mirror(uv + o * vec2f(1.0 / ratio, 1.0)), incoming);
        }
        c /= f32(TAPS);
        if (c.a > 0.0) { c = vec4f(c.rgb / c.a, c.a); } else { c = vec4f(0.0); }
        c = vec4f(c.rgb * (1.0 - 0.35 * f), c.a);
    }
    return mix(c, params.color, lid);
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
