// Port of WaterDrop.glsl from gl-transitions (author: Paweł Płóciennik, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WaterDrop.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn gmod2(v: vec2f, y: f32) -> vec2f { return v - y * floor(v / y); }

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - gmod2(v, 2.0)); }

// Height of the water, from -1 to 1, at a distance s inside the front.
fn wave(s: f32, k: f32, lambda: f32, t: f32) -> f32 {
    let env = smoothstep(-0.3 * lambda, 0.6 * lambda, s) * exp(-s / (3.5 * lambda));
    // The ripples run out through the train, faster than the train itself spreads.
    return env * sin(k * s + params.speed * t);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // `center` is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let k = 2.0 * max(params.amplitude, 1.0);
    let lambda = 6.2831853 / k;
    // Measured in square pixels, so the ripples are round.
    let q = (uv - center) * vec2f(ratio, 1.0);
    let r = length(q);
    let dir = select(vec2f(0.0), q / r, r > 0.0);
    let far = max(center, 1.0 - center) * vec2f(ratio, 1.0);
    let big_r = length(far);
    let edge = 0.35 * lambda;
    let soft = 0.1 * lambda;
    // The front spreads out, slowing down a little, from just before the drop hits until
    // its revealed area is past the farthest corner.
    let t = progress;
    let e = mix(t, 1.0 - (1.0 - t) * (1.0 - t), 0.4);
    let front = mix(-0.3 * lambda, big_r + edge + soft + 0.01, e);
    let s = front - r;
    var calm = 1.0 - smoothstep(0.55, 1.0, t);
    calm *= calm;
    // Slope of the water along the radius, normalized to at most about 1 (one-sided at the center).
    let d = 0.02 * lambda;
    let r0 = max(r - d, 0.0);
    let slope = calm * (wave(front - r - d, k, lambda, t) - wave(front - r0, k, lambda, t)) / ((r + d - r0) * k);
    let offset = dir * slope * params.refraction / vec2f(ratio, 1.0);
    let ca = from_color(mirror(uv - offset));
    let cb = to_color(mirror(uv - offset));
    let m = smoothstep(edge - soft, edge + soft, s);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    var c = mix(vec4f(ca.rgb * ca.a, ca.a), vec4f(cb.rgb * cb.a, cb.a), m);
    let h = calm * wave(s, k, lambda, t);
    let lit = -dot(dir, normalize(vec2f(-0.6, 0.8))) * slope;
    let glint = params.highlight * (0.2 * h + 0.6 * smoothstep(0.2, 0.9, lit) - 0.3 * smoothstep(0.2, 0.9, -lit));
    c = vec4f(clamp(c.rgb + glint * c.a, vec3f(0.0), vec3f(c.a)), c.a);
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
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
