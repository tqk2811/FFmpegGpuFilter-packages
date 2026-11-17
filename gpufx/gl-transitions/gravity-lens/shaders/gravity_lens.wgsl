// Port of GravityLens.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GravityLens.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// How far past the farthest corner the disk grows, so the frame is fully covered briefly.
const OVERSHOOT: f32 = 0.12;
// When the frame is covered: the swallow takes a little longer than the release.
const PEAK: f32 = 0.55;
const AA: f32 = 0.002;
const WARM: vec3f = vec3f(1.0, 0.86, 0.68);

// Fold the coordinates back into the frame, so the picture stays filled without smearing its border.
fn mirrored(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return mix(m, 2.0 - m, step(vec2f(1.0), m));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // `center` is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    // The disk grows with an accelerating swallow, then shrinks back a little faster.
    let swallowing = progress < PEAK;
    let u = select((1.0 - progress) / (1.0 - PEAK), progress / PEAK, swallowing);
    let u2 = u * u;
    let k = u2 * (0.6 + 0.4 * u2);
    let aspect = vec2f(ratio, 1.0);
    let far = max(center, 1.0 - center) * aspect;
    let rh = length(far) * (1.0 + OVERSHOOT) * k;
    // Radius where the light from right behind the disk shows up as a ring.
    let re = rh * (1.0 + max(params.strength, 0.0));
    let d = (uv - center) * aspect;
    let r = max(length(d), 1e-5);
    // A point mass deflects the light by an angle falling off as 1/r.
    let q = mirrored(center + d * (1.0 - re * re / (r * r)) / aspect);
    var c = select(to_color(q), from_color(q), swallowing);
    let amount = smoothstep(0.0, 0.04, rh);
    let inner = clamp((r - rh) / (re - rh + 1e-4), 0.0, 1.0);
    var rgb = c.rgb * (1.0 - 0.7 * amount * (1.0 - inner * inner * (3.0 - 2.0 * inner)));
    let g = max(params.glow, 0.0) * amount;
    let einstein = (r - re) / (0.3 * (re - rh) + 0.01);
    let photon = max(r - rh, 0.0) / (0.006 + 0.012 * rh);
    let light = g * (0.7 * exp(-einstein * einstein) + 1.6 * exp(-photon * photon));
    rgb = min(rgb * (1.0 + light) + WARM * (0.35 * light * c.a), vec3f(1.0));
    c = vec4f(rgb, c.a);
    // Antialiased horizon, kept inside the disk so it vanishes with it.
    let cov = clamp((rh - r) / (2.0 * AA), 0.0, 1.0);
    return mix(c, params.hole, cov);
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
