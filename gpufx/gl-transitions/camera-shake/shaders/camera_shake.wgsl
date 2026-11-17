// Port of CameraShake.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CameraShake.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 10;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

// The camera position at jolt key k: offset (x, y) and roll, each in -1..1.
fn jolt(k: f32) -> vec3f {
    let a = 2.4 * k + 1.2 * hash12(vec2f(k, 11.0));
    let m = 0.55 + 0.45 * hash12(vec2f(k, 23.0));
    return vec3f(m * cos(a), m * sin(a), 2.0 * hash12(vec2f(k, 37.0)) - 1.0);
}

fn envelope(t: f32) -> f32 {
    let h = clamp(1.6 * (1.0 - abs(2.0 * t - 1.0)), 0.0, 1.0);
    return h * h * (3.0 - 2.0 * h);
}

// The picture seen by the camera at time t (in progress units), premultiplied.
fn shot(uv: vec2f, t: f32, incoming: bool, ratio: f32) -> vec4f {
    let env = envelope(t);
    // A key every 1/jolts, one of them exactly at the cut.
    let s = (t - 0.5) * params.jolts;
    let k = floor(s);
    let g = 1.0 - (s - k);
    let e = 1.0 - g * g * g;
    let j = mix(jolt(k), jolt(k + 1.0), e) * env;
    let omax = 0.14 * params.strength * env;
    let rmax = 0.07 * params.strength * env;
    let off = j.xy * omax;
    let roll = j.z * rmax;
    // Zoom in just enough that the frame edges never show.
    let zoom = (cos(rmax) + sin(rmax) * max(ratio, 1.0 / ratio)) / (1.0 - 2.0 * omax);
    var q = (uv - 0.5) * vec2f(ratio, 1.0);
    q = mat2x2f(cos(roll), sin(roll), -sin(roll), cos(roll)) * q / zoom;
    let p = mirror(q / vec2f(ratio, 1.0) + 0.5 + off);
    let c = select(from_color(p), to_color(p), incoming);
    return vec4f(c.rgb * c.a, c.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let jolts = max(params.jolts, 1.0);
    let open = envelope(progress);
    let shutter = 0.8 * params.blur / jolts * open;
    let lag = 0.2 * params.split / jolts * open;
    var sum_r = vec2f(0.0);
    var sum_g = vec2f(0.0);
    var sum_b = vec2f(0.0);
    var wsum = 0.0;
    for (var i = 0; i < TAPS; i++) {
        let u = (f32(i) + 0.5) / f32(TAPS) - 0.5;
        let t = progress + u * shutter;
        let w = 1.0 - 1.4 * abs(u);
        // The cut happens during the exposure: the channels of a tap show the same clip.
        let incoming = t >= 0.5;
        let r = shot(uv, t + lag, incoming, ratio);
        let c = shot(uv, t, incoming, ratio);
        let b = shot(uv, t - lag, incoming, ratio);
        sum_r += w * r.ra;
        sum_g += w * c.ga;
        sum_b += w * b.ba;
        wsum += w;
    }
    let alpha = (sum_r.y + sum_g.y + sum_b.y) / (3.0 * wsum);
    if (alpha <= 0.0) { return vec4f(0.0); }
    return vec4f(sum_r.x / max(sum_r.y, 1e-5), sum_g.x / max(sum_g.y, 1e-5), sum_b.x / max(sum_b.y, 1e-5), alpha);
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
