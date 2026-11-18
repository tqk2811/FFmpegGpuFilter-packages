// Port of PaperTear.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaperTear.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn tri(x: f32) -> f32 {
    return abs(fract(x) - 0.5) - 0.25;
}

// Horizontal position of the tear at height y: smooth meanders...
fn meander(y: f32, ratio: f32) -> f32 {
    return 0.5 * ratio + params.roughness * (0.5 * sin(y * 4.7 + 1.3) + 0.25 * sin(y * 11.3 + 4.1));
}

// ...and sharp jags.
fn tear(y: f32, ratio: f32) -> f32 {
    return meander(y, ratio) + params.roughness * (0.1 * sin(y * 29.0 + 0.7) + 0.35 * tri(y * 19.0 + sin(y * 7.0)) + 0.12 * tri(y * 47.0 + 0.6 * sin(y * 13.0)));
}

fn fibers(y: f32, seed: f32) -> f32 {
    return params.rim * (0.7 + 0.3 * sin(y * 37.0 + seed) + 0.4 * tri(y * 83.0 + seed));
}

// The left half (or the mirrored right half) slides out, its top leaning away first: from a point
// on screen to the point of the paper (the frame edges stay covered).
fn unfold(q: vec2f, away: f32, lean: f32) -> vec2f {
    return vec2f(q.x + away + lean * q.y, q.y);
}

// A torn half over bg; e: distance past the torn edge, limit: how far the fibers reach, aa: edge softness.
fn torn(bg: vec4f, col: vec4f, e: f32, limit: f32, aa: f32) -> vec4f {
    let paper = params.paper;
    let c = vec4f(mix(col.rgb, paper.rgb, clamp(0.5 + e / aa, 0.0, 1.0) * paper.a), col.a);
    return mix(bg, c, clamp(0.5 - (e - limit) / aa, 0.0, 1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let away = p * p * (0.5 * ratio + 0.1 + params.roughness + 2.0 * params.rim); // far enough to leave the frame
    let lean = params.tilt * p * (2.0 - p);
    let fiber = smoothstep(0.0, 0.15, p); // no torn edge on the intact picture
    let aa = 0.002 * fiber + 1e-6;
    let q = vec2f(uv.x * ratio, uv.y);
    let l = unfold(q, away, lean);
    let r = unfold(vec2f(ratio - q.x, q.y), away, lean);
    let el = l.x - tear(l.y, ratio); // > 0 right of the left half's torn edge
    let er = r.x - (ratio - tear(r.y, ratio)); // > 0 left of the right half's torn edge
    let sq = q - vec2f(0.01, 0.0);
    let dl = unfold(sq, away, lean).x - meander(sq.y, ratio);
    let dr = unfold(vec2f(ratio - sq.x, sq.y), away, lean).x - (ratio - meander(sq.y, ratio));
    let b = to_color(uv);
    let shadow = params.shadow;
    let sh = shadow.a * (1.0 - smoothstep(-0.02, 0.08, min(dl, dr)));
    var c = vec4f(mix(b.rgb, shadow.rgb, sh), b.a);
    if (r.x >= 0.0) {
        c = torn(c, from_color(vec2f(1.0 - r.x / ratio, r.y)), er, fibers(r.y, 2.0) * 1.5 * fiber, aa);
    }
    if (l.x >= 0.0) {
        c = torn(c, from_color(vec2f(l.x / ratio, l.y)), el, fibers(l.y, 0.0) * fiber, aa);
    }
    return c;
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
