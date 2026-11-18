// Port of SmokeDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SmokeDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn vnoise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
        mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

fn fbm(v0: vec2f) -> f32 {
    var v = v0;
    var sum = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 4; i++) {
        sum += amp * vnoise(v);
        v = mat2x2f(1.6, 1.2, -1.2, 1.6) * v + 5.3;
        amp *= 0.5;
    }
    return sum / 0.9375;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let spread = params.spread;
    let p = progress;
    let pos = (uv - 0.5) * vec2f(ratio, 1.0);

    // Where along the drift the pixel is: 0 on the side the smoke comes from, 1 on the other.
    let len = length(params.direction);
    var dir = vec2f(0.0);
    if (len > 1e-4) { dir = params.direction / len; }
    let ext = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + 1e-4;
    var along = 0.5;
    if (len > 1e-4) { along = 0.5 + 0.5 * dot(pos, dir) / ext; }

    // The smoke rolls in (until 0.45), covers the whole frame, then thins out (from 0.55), each
    // side of the frame in turn.
    let arrive = (p / 0.45) * (1.0 + spread) - spread * along;
    let leave = ((p - 0.55) / 0.45) * (1.0 + spread) - spread * along;
    let body = smoothstep(0.0, 1.0, arrive) * (1.0 - smoothstep(0.0, 1.0, leave));
    // The clips switch while the smoke is fully dense everywhere.
    let m = smoothstep(0.48, 0.52, p);
    if (body <= 0.0) {
        if (m < 0.5) { return from_color(uv); }
        return to_color(uv);
    }

    let q = (pos - params.direction * (p - 0.5)) * params.scale;
    let churn = vec2f(0.5 * p, -0.35 * p);
    let warp = vec2f(fbm(q + vec2f(3.1, 1.7) + churn), fbm(q + vec2f(8.3, 2.8) - churn));
    let w = q + 1.1 * (warp - 0.5);
    let n = fbm(w);
    // The billows catch the light from above: brighter where the smoke rises toward it (on the
    // coarse octave only, which shapes them).
    let lit = 0.53 * (vnoise(w) - vnoise(w + vec2f(0.0, 0.2)));
    let wisp = vnoise(w * 3.3 - 2.0 * churn) - 0.5;

    let edge = 2.0 * body - (1.0 - smoothstep(0.1, 0.6, n)) + 1.6 * body * (1.0 - body) * wisp;
    let d = smoothstep(0.0, params.softness, edge) * mix(0.5, 1.0, smoothstep(0.2, 0.9, body));

    var base: vec4f;
    if (m <= 0.0) {
        base = from_color(uv);
    } else if (m >= 1.0) {
        base = to_color(uv);
    } else {
        let a = from_color(uv);
        let b = to_color(uv);
        base = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);
        if (base.a > 0.0) { base = vec4f(base.rgb / base.a, base.a); } else { base = vec4f(0.0); }
    }
    if (d <= 0.0) { return base; }

    var shade = 0.92 + 1.3 * lit;
    shade *= mix(0.76, 1.04, smoothstep(0.25, 0.75, n));
    shade = mix(1.0, shade, 0.3 + 0.7 * d);
    let smoke = clamp(params.color.rgb * shade, vec3f(0.0), vec3f(1.0));

    // The smoke color mixes as straight RGBA, like every fill color.
    return mix(base, vec4f(smoke, params.color.a), d);
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
