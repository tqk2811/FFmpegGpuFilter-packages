// Port of Faint.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Faint.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The original fades to black, which fills the frame at the midpoint; the default color here
// is a near black so that frame still differs from black (see the manifest).
const TAPS: i32 = 8;

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn image(uv: vec2f, incoming: bool) -> vec4f {
    let c = select(from_color(mirror(uv)), to_color(mirror(uv)), incoming);
    return vec4f(c.rgb * c.a, c.a);
}

// A small blur disc around uv (premultiplied), golden-angle taps.
fn soft(uv: vec2f, r: f32, incoming: bool, ratio: f32) -> vec4f {
    var s = vec4f(0.0);
    for (var i = 0; i < TAPS; i++) {
        let k = f32(i) + 0.5;
        let a = 2.39996 * k;
        s += image(uv + sqrt(k / f32(TAPS)) * vec2f(cos(a) / ratio, sin(a)) * r, incoming);
    }
    return s / f32(TAPS);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let color = params.color;
    let p = progress;
    let incoming = p >= 0.5;
    // How far gone the viewer is: 0 at both ends, 1 at the cut.
    let a = select(2.0 * p, 2.0 - 2.0 * p, incoming);
    let g = select(a, a * sqrt(a), incoming);
    // The view closes in two heartbeat throbs.
    let closing = g - sin(12.566371 * g) / 12.566371;
    let sway = sin(9.0 * p + 1.3);
    let off = params.separation * smoothstep(0.0, 0.5, a) * vec2f(1.0, 0.25 * sway) * vec2f(1.0 / ratio, 1.0);
    let r = 0.03 * params.blur * a;
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let d = length(q) / (0.5 * length(vec2f(ratio, 1.0)));
    let big_r = mix(1.8, 0.05, closing);
    let v = smoothstep(0.6 * big_r - 0.02, big_r + 0.001, d);
    if (v >= 1.0) { return color; }
    var c: vec4f;
    if (a <= 0.0) {
        c = image(uv, incoming);
    } else {
        c = 0.5 * (soft(uv + off, r, incoming, ratio) + soft(uv - off, r, incoming, ratio));
        // At the darkest moment the two clips melt into each other, so the cut never pops.
        let w = smoothstep(0.46, 0.54, p);
        if (w > 0.0 && w < 1.0) {
            let other = 0.5 * (soft(uv + off, r, !incoming, ratio) + soft(uv - off, r, !incoming, ratio));
            c = select(mix(c, other, w), mix(other, c, w), incoming);
        }
    }
    c = select(vec4f(0.0), vec4f(c.rgb / c.a, c.a), c.a > 0.0);
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    c = vec4f(mix(c.rgb, vec3f(lum), 0.5 * a) * (1.0 - 0.3 * a), c.a);
    return mix(c, color, v);
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
