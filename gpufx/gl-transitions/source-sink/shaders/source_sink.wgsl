// Port of SourceSink.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SourceSink.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn cmul(a: vec2f, b: vec2f) -> vec2f { return vec2f(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }
fn cdiv(a: vec2f, b: vec2f) -> vec2f { return vec2f(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / max(dot(b, b), 1e-12); }

// The outer field lines bring in content from beyond the frame.
fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// w = (z - A) / (z - B) sends source and sink to 0 and infinity: scaling w slides points along the circular field lines.
fn unflow(w: vec2f, a0: vec2f, b0: vec2f, asp: vec2f, s: f32, a: f32) -> vec2f {
    let v = cmul(w, exp(s) * vec2f(cos(a), sin(a)));
    return mirror(cdiv(a0 - cmul(b0, v), vec2f(1.0, 0.0) - v) / asp + 0.5);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let t = progress;
    let asp = vec2f(globals.size.x / globals.size.y, 1.0);
    // The source and sink options are given y down.
    let a0 = (vec2f(params.source.x, 1.0 - params.source.y) - 0.5) * asp;
    var b0 = (vec2f(params.sink.x, 1.0 - params.sink.y) - 0.5) * asp;
    if (length(b0 - a0) < 0.01) { b0 = a0 + vec2f(0.01, 0.0); }
    let ab = length(b0 - a0);
    let z = (uv - 0.5) * asp;
    let w = cdiv(z - a0, z - b0);

    let e = t * t * (3.0 - 2.0 * t);
    // The outer field lines loop through off-frame space: slow them down so little of it streams in.
    let h = 0.5 - 0.5 * w.x * inverseSqrt(max(dot(w, w), 1e-12));
    let a = clamp(params.swirl, -2.5, 2.5) * h;
    var fc = from_color(unflow(w, a0, b0, asp, -params.flow * h * e, -a * e));
    var tc = to_color(unflow(w, a0, b0, asp, params.flow * h * (1.0 - e), a * (1.0 - e)));

    // Seam: the Apollonius circle |w| = k, k = (t / (1 - t))^1.8, written with q = k^2 / (1 + k^2) so nothing overflows.
    let p0 = pow(t, 3.6);
    let p1 = pow(1.0 - t, 3.6);
    let q = p0 / (p0 + p1);
    let za = z - a0;
    let zb = z - b0;
    let d = ((1.0 - q) * dot(za, za) - q * dot(zb, zb))
        / (length((1.0 - 2.0 * q) * z - (1.0 - q) * a0 + q * b0) + sqrt(q * (1.0 - q)) * ab);
    let radius = sqrt(q * (1.0 - q)) * ab / max(abs(1.0 - 2.0 * q), 1e-4);
    let rim = clamp(0.3 * radius, 1e-4, 0.07);

    let m = smoothstep(-0.003, 0.003, d + 0.003 * (1.0 - 2.0 * t));
    let env = params.shading * 4.0 * t * (1.0 - t);
    fc = vec4f(fc.rgb * (1.0 - 0.55 * env * exp(-max(d, 0.0) / rim)), fc.a);
    tc = vec4f(tc.rgb + 0.3 * env * exp(-d * d / (0.08 * rim * rim)) * (1.0 - m), tc.a);
    return mix(tc, fc, m);
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
