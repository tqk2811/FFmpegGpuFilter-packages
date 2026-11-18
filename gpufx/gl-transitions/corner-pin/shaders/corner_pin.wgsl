// Port of CornerPin.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CornerPin.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn cross2(a: vec2f, b: vec2f) -> f32 { return a.x * b.y - a.y * b.x; }

// Back-out ease: exactly 1 at x = 1, overshooting before it.
fn snap(x0: f32) -> f32 {
    let x = x0 - 1.0;
    let c = 1.70158 * params.overshoot;
    return 1.0 + (c + 1.0) * x * x * x + c * x * x;
}

fn corner(goal: vec2f, x: f32, grow: f32) -> vec2f {
    return mix(0.5 + (goal - 0.5) * params.start * grow, goal, snap(x));
}

// Signed distance to the edge e0 -> e1 of the counterclockwise card, positive inside.
fn edge(p: vec2f, e0: vec2f, e1: vec2f) -> f32 {
    return cross2(e1 - e0, p - e0) / max(length(e1 - e0), 1e-6);
}

// An edge loses its softness as both its corners land, so it meets the frame border without a seam.
fn cover(dist: f32, x0: f32, x1: f32) -> f32 {
    return clamp(dist / (0.002 * sqrt(1.0 - min(x0, x1)) + 1e-6) + 0.5, 0.0, 1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress;
    let asp = vec2f(ratio, 1.0);
    let appear = smoothstep(0.0, 0.12, t);
    // Kept above 0 so the quad never collapses to a point.
    let grow = max(appear, 1e-3);
    let xa = clamp((t - 0.10) / 0.32, 0.0, 1.0);
    let xb = clamp((t - 0.28) / 0.32, 0.0, 1.0);
    let xc = clamp((t - 0.46) / 0.32, 0.0, 1.0);
    let xd = clamp((t - 0.64) / 0.32, 0.0, 1.0);
    let a = corner(vec2f(0.0, 1.0), xa, grow) * asp;
    let b = corner(vec2f(1.0, 1.0), xb, grow) * asp;
    let c = corner(vec2f(1.0, 0.0), xc, grow) * asp;
    let d = corner(vec2f(0.0, 0.0), xd, grow) * asp;
    let p = uv * asp;

    // Inverse of the projective map sending the unit square to d (0,0), c (1,0), b (1,1), a (0,1).
    let s = d - c + b - a;
    let e1 = c - b;
    let e2 = a - b;
    let den = cross2(e1, e2);
    let g = cross2(s, e2) / den;
    let h = cross2(e1, s) / den;
    let cu = vec3f(c - d + g * c, g);
    let cv = vec3f(a - d + h * a, h);
    let c1 = vec3f(d, 1.0);
    let hp = vec3f(p, 1.0);
    var w = dot(cross(cu, cv), hp);
    // Past the card's horizon w crosses 0: keep it finite there, the card does not cover it.
    w = select(max(w, 1e-6), min(w, -1e-6), w < 0.0);
    let q = vec2f(dot(cross(cv, c1), hp), dot(cross(c1, cu), hp)) / w;

    var inside = min(min(cover(edge(p, d, c), xd, xc), cover(edge(p, c, b), xc, xb)),
                     min(cover(edge(p, b, a), xb, xa), cover(edge(p, a, d), xa, xd)));
    inside *= smoothstep(0.0, 0.02, t);

    let lift = 1.0 - smoothstep(0.3, 1.0, xd);
    let ps = p - vec2f(0.012, -0.02) * lift * grow;
    let blur = 0.025 * grow;
    let sd = min(min(edge(ps, d, c), edge(ps, c, b)), min(edge(ps, b, a), edge(ps, a, d)));
    let sh = params.shadow * lift * appear * smoothstep(-blur, blur, sd);

    let fr = from_color(uv);
    return mix(vec4f(fr.rgb * (1.0 - sh), fr.a), to_color(clamp(q, vec2f(0.0), vec2f(1.0))), inside);
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
