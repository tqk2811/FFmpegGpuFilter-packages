// Port of SlideProjector.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SlideProjector.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;
const MOUNT: f32 = 0.07;
const CLEAR: f32 = 1.07;
const TAPS: i32 = 16;

fn hash(n: f32) -> f32 {
    var p3 = fract(vec3f(n) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Height of the first picture on the screen: a short dip as the lift arm grabs the slide,
// then it is jerked up, still accelerating as it leaves the frame.
fn lift_out(p: f32) -> f32 {
    let u = clamp((p - 0.05) / 0.3, 0.0, 1.0);
    let d = clamp(p / 0.12, 0.0, 1.0);
    let s = sin(PI * d);
    return CLEAR * u * u * (0.6 + 0.4 * u) - (0.004 + 0.012 * params.bounce) * s * s;
}

// Height of the second picture: it falls into the gate under gravity, then makes two small hops.
fn drop_in(p: f32) -> f32 {
    let v = clamp((p - 0.37) / 0.19, 0.0, 1.0);
    let y = CLEAR * (1.0 - v * v);
    let w = clamp((p - 0.56) / 0.22, 0.0, 1.0);
    let h = 0.06 * params.bounce;
    // Hop lengths in proportion to the square root of their heights (1 and 0.15).
    let s1 = clamp(w / 0.72, 0.0, 1.0);
    let s2 = clamp((w - 0.72) / 0.28, 0.0, 1.0);
    return y + h * 4.0 * s1 * (1.0 - s1) + h * 0.15 * 4.0 * s2 * (1.0 - s2);
}

// How far out of focus the projection is (0 to 1): the first slide leaves the focal plane as it is
// lifted, the second lands out of focus, sharpens, overshoots and comes back sharp.
fn blur_amount(p: f32) -> f32 {
    let s = clamp((p - 0.56) / 0.4, 0.0, 1.0);
    let k = 1.0 - s;
    let hunt = abs(cos(s * PI * 1.5)) * k;
    return smoothstep(0.04, 0.3, p) * select(hunt, 1.0, p < 0.56);
}

fn band(y: f32, a: f32, b: f32, aa: f32) -> f32 {
    return clamp(min(y - a, b - y) / aa + 0.5, 0.0, 1.0);
}

// The gate seen on the screen at q with the first slide at height yf and the second at height yt,
// premultiplied; light is the brightness of the bare lamp there and shade the one of the pictures.
fn gate(q: vec2f, yf: f32, yt: f32, light: f32, shade: f32) -> vec4f {
    // Edges get sharp as a slide comes to rest, so that it then covers the whole frame.
    let af = 0.0015 * min(abs(yf) * 400.0, 1.0) + 1e-6;
    let at = 0.0015 * min(abs(yt) * 400.0, 1.0) + 1e-6;
    let lamp = params.lamp_color;
    var c = vec4f(lamp.rgb * lamp.a * light, lamp.a);
    let mf = band(q.y, yf - MOUNT, yf + 1.0 + MOUNT, af);
    let mt = band(q.y, yt - MOUNT, yt + 1.0 + MOUNT, at);
    c = vec4f(c.rgb * (1.0 - 0.96 * max(mf, mt)), c.a);
    let pf = band(q.y, yf, yf + 1.0, af);
    if (pf > 0.0) {
        let t = from_color(vec2f(q.x, q.y - yf));
        c = mix(c, vec4f(t.rgb * t.a * shade, t.a), pf);
    }
    let pt = band(q.y, yt, yt + 1.0, at);
    if (pt > 0.0) {
        let t = to_color(vec2f(q.x, q.y - yt));
        c = mix(c, vec4f(t.rgb * t.a * shade, t.a), pt);
    }
    return c;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = progress;
    let ratio = globals.size.x / globals.size.y;

    let yf = lift_out(p);
    let yt = drop_in(p);
    // Vertical speed of the slide that moves (one at a time), for the motion blur.
    let dp = 0.004;
    let vf = (lift_out(p + dp) - lift_out(p - dp)) / (2.0 * dp);
    let vt = (drop_in(p + dp) - drop_in(p - dp)) / (2.0 * dp);
    let smear = min(max(abs(vf), abs(vt)) * 0.012, 0.07);

    let b = blur_amount(p);
    let radius = params.defocus * 0.02 * b;
    let zoom = 1.0 + 0.025 * params.defocus * b;
    let c0 = (uv - 0.5) / zoom + 0.5;

    let env = smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.72, 1.0, p));
    let fc = p * 30.0;
    let fl = mix(hash(floor(fc)), hash(floor(fc) + 1.0), smoothstep(0.3, 0.7, fract(fc)));
    let d = (uv - 0.5) * vec2f(ratio, 1.0) / (0.5 * sqrt(ratio * ratio + 1.0));
    let light = (1.0 - 0.3 * dot(d, d)) * (1.0 - 0.3 * params.flicker * fl * env);
    let shade = mix(1.0, 0.92 * light, env);

    var c: vec4f;
    if (radius + smear < 1e-4) {
        c = gate(c0, yf, yt, light, shade);
    } else {
        c = vec4f(0.0);
        for (var i = 0; i < TAPS; i++) {
            let fi = f32(i);
            let a = fi * 2.39996;
            var o = sqrt((fi + 0.5) / f32(TAPS)) * vec2f(cos(a) / ratio, sin(a)) * radius;
            o.y += ((fi + 0.5) / f32(TAPS) - 0.5) * smear;
            // The gate is the frame: fold the taps back so its edges stay sharp.
            let q = 1.0 - abs(1.0 - abs(c0 + o));
            c += gate(q, yf, yt, light, shade);
        }
        c /= f32(TAPS);
    }
    return select(vec4f(0.0), vec4f(c.rgb / max(c.a, 1e-6), c.a), c.a > 0.0);
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
