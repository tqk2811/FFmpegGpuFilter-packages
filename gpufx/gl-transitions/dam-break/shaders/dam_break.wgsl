// Port of DamBreak.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DamBreak.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(v.xyx * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn vnoise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
        mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x), f.y);
}

// Tau-normalized so a tiny tau never squares below the float range.
fn flow_area(a: f32, x: f32, tau: f32) -> f32 {
    let p = 2.0 - a / tau;
    let q = 2.0 - x / tau;
    return tau * (p * p * p - q * q * q) / 27.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let leftward = params.leftward != 0u;
    let t = progress;
    let big_l = ratio;
    let u = select(uv.x, 1.0 - uv.x, leftward);
    // x in frame heights from the dam at the open edge; with unit depth and wave speed the free
    // surface is ((2 tau - x) / (3 tau))^2.
    let x = (u - 1.0) * big_l;
    let tau = max(1.6 * max(big_l, 0.8) * pow(t, 1.4), 1e-4);
    let drain = 1.0 - smoothstep(0.45, 1.0, t);

    let a = max(-big_l, -tau);
    let xc = min(x, 2.0 * tau);
    var big_m = max(min(xc, a) + big_l, 0.0);
    if (xc > a) { big_m += flow_area(a, xc, tau); }
    let mt = (a + big_l) + flow_area(a, 2.0 * tau, tau);

    // r is capped at 2 so r * r stays small; past sqrt(1 + k) the smooth-min is already 1.
    let r = min(max(2.0 * tau - x, 0.0), 6.0 * tau) / (3.0 * tau);
    let k = 0.12;
    let sk = clamp(0.5 + 0.5 * (r * r - 1.0) / k, 0.0, 1.0);
    var hs = mix(r * r, 1.0, sk) - k * sk * (1.0 - sk);
    // The polynomial smooth-min's derivative reduces to (1 - sk) * d(r^2)/dx.
    var dhs = -(1.0 - sk) * 2.0 * r / (3.0 * tau);
    // tau has a floor, so the flow fades in to keep the open edge full at progress 0.
    let e = smoothstep(0.0, 0.02, t);
    hs = mix(1.0, hs, e);
    dhs *= e;

    let moving = clamp(1.0 - hs, 0.0, 1.0);
    let ramp = min(moving * 4.0, 1.0) * (1.0 - t);
    let ph = 34.0 * x - 60.0 * t;
    let ph2 = 71.0 * x - 115.0 * t + 1.7;
    let wave = (0.014 * sin(ph) + 0.005 * sin(ph2)) * ramp;
    let dwave = (0.014 * 34.0 * cos(ph) + 0.005 * 71.0 * cos(ph2)) * ramp;
    let h = (hs + wave) * drain;
    let slope = (dhs + dwave) * drain;

    let d = h - uv.y;
    let in_water = smoothstep(-1e-5, 0.003 * min(t * 20.0, 1.0) + 1e-5, d);
    let src = vec2f(mix(u, big_m / mt, e), uv.y / max(h, 1e-4));
    let img0 = from_color(clamp(select(src, vec2f(1.0 - src.x, src.y), leftward), vec2f(0.0), vec2f(1.0)));

    let steep = clamp(-dhs * drain * 1.5, 0.0, 1.0);
    let lit = clamp(slope * 2.5 + 0.6, 0.0, 1.0);
    let dd = max(d, 0.0);
    let near = exp(-dd / 0.08);
    var rgb = img0.rgb * (1.0 - moving * (0.3 * (1.0 - src.y) + 0.2 * steep) - 0.25 * moving * near * (1.0 - lit));

    let fast = min(moving * 2.0, 1.0);
    let fq = vec2f((x - 0.9 * t) * 16.0, d * 30.0);
    let froth = vnoise(fq) * 0.6 + vnoise(fq * vec2f(2.3, 2.7) + 5.1) * 0.4;
    let foam_depth = (0.006 + 0.05 * fast) * (0.5 + froth);
    var fm = params.foam * fast * smoothstep(0.0, 0.003, d) * (1.0 - smoothstep(0.6, 1.0, d / foam_depth));
    fm *= smoothstep(0.25, 0.55, froth + 0.3 * fast - 0.15);
    rgb = mix(rgb, vec3f(0.94, 0.97, 1.0), fm);

    let streak = 0.5 + 0.5 * vnoise(vec2f((x - 1.2 * t) * 8.0, 0.5));
    let spec = params.gloss * fast * (0.2 + 0.8 * lit) * streak;
    let band = exp(-abs(d - 0.03 - 0.03 * fast) / 0.012);
    rgb += spec * (0.8 * exp(-dd / 0.008) * smoothstep(0.0, 0.003, d) + 0.35 * band * (1.0 - fm) + 0.1 * near);
    rgb = min(rgb, vec3f(1.0));
    let img = vec4f(rgb, img0.a);

    let bg0 = to_color(uv);
    let above = -d;
    let shadow = exp(-max(above, 0.0) / 0.05) * smoothstep(-0.002, 0.0, above) * min(moving * 3.0, 1.0);
    let bg = vec4f(bg0.rgb * (1.0 - 0.35 * shadow * smoothstep(0.0, 0.3, drain) * smoothstep(0.0, 0.05, t)), bg0.a);
    return mix(bg, img, in_water);
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
