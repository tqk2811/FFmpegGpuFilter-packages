// Port of Revolve.glsl from gl-transitions (author: bread, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Revolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn sat(x: f32) -> f32 { return clamp(x, 0.0, 1.0); }

fn ease(x_in: f32) -> f32 {
    let x = sat(x_in);
    return x * x * (3.0 - 2.0 * x);
}

fn envelope(t: f32) -> f32 {
    return ease((t - 0.10) / 0.33) * (1.0 - ease((t - 0.43) / 0.29));
}

fn rotate2(p: vec2f, a: f32) -> vec2f {
    let s = sin(a);
    let c = cos(a);
    return vec2f(c * p.x - s * p.y, s * p.x + c * p.y);
}

fn center() -> vec2f { return vec2f(params.center.x, 1.0 - params.center.y); }

fn warp_uv(uv: vec2f, t: f32, ratio: f32) -> vec2f {
    let e = envelope(t);
    var p = uv - center();
    p.x *= ratio;
    let r = length(p);
    let edge_spin = params.max_rotation * e;
    let core_spin = params.swirl * e * pow(1.0 - sat(r / 0.96), 1.55);
    p = rotate2(p, -params.direction * (edge_spin + core_spin));
    p /= 1.0 + (params.peak_zoom - 1.0) * pow(e, 0.85);
    let rr = length(p);
    p *= 1.0 + params.barrel * e * rr * rr * 2.8;
    p.x /= ratio;
    return clamp(p + center(), vec2f(0.001), vec2f(0.999));
}

fn sample_revolve(uv: vec2f, t: f32, ratio: f32) -> vec4f {
    let p = warp_uv(uv, t, ratio);
    return mix(from_color(p), to_color(p), smoothstep(params.switch_start, params.switch_end, t));
}

fn transition(uv: vec2f, progress_in: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Unlike the original, progress is mapped onto 0..0.72, where the swirl settles: the
    // original held the second clip still for its last 28%.
    let progress = progress_in * 0.72;
    let e = envelope(progress);
    let span = 0.060 * params.motion_blur * e;
    var color = vec4f(0.0);
    var total = 0.0;
    for (var i = -8; i <= 8; i++) {
        let x = f32(i) / 8.0;
        var w = 1.0 - abs(x);
        w = w * w + 0.01;
        color += sample_revolve(uv, sat(progress + x * span), ratio) * w;
        total += w;
    }
    color /= total;
    var q = uv - vec2f(0.5);
    q.x *= ratio;
    let vignette = 1.0 - params.shadow * e * smoothstep(0.35, 0.95, length(q));
    return vec4f(color.rgb * vignette, color.a);
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
