// Port of BeadUp.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BeadUp.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn fold(p: vec2f) -> vec2f {
    let m = p - 2.0 * floor(p / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn hash3(p: vec2f) -> vec3f {
    var p3 = fract(vec3f(p.x, p.y, p.x) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// The liquid at x (frame heights): x = signed distance into the liquid (negative where dry), y = height.
fn liquid(x: vec2f, p: f32) -> vec2f {
    let cs = 1.0 / max(params.holes, 1.0);
    // The rims and beads stay small next to the holes, so the beads keep round when holes are many.
    let w = clamp(params.rim, 0.001, 0.15 * cs);
    let cell = floor(x / cs);
    var d1 = 1e3;
    var d2 = 1e3;
    var c1 = vec2f(0.0);
    var c2 = vec2f(1.0, 0.0);
    var s1 = 0.0;
    var s2 = 0.0;
    var h_rim = 0.0;
    for (var j = -2; j <= 2; j++) {
        for (var i = -2; i <= 2; i++) {
            let n = cell + vec2f(f32(i), f32(j));
            let h = hash3(n + 17.0);
            let c = (n + 0.5 + 0.75 * (h.xy - 0.5)) * cs;
            let age = p - 0.28 * h.z;
            if (age <= 0.0) { continue; }
            let d = length(x - c) - 2.3 * cs * age - 0.6 * smoothstep(0.6, 1.0, p);
            // The rolled rim in front of the hole, which gathers as the hole opens instead of popping in at full size.
            let wh = w * smoothstep(0.0, 0.06, age);
            h_rim = max(h_rim, sqrt(max(wh * wh - (d - wh) * (d - wh), 0.0)));
            if (d < d1) { d2 = d1; c2 = c1; s2 = s1; d1 = d; c1 = c; s1 = h.x; }
            else if (d < d2) { d2 = d; c2 = c; s2 = h.x; }
        }
    }
    h_rim *= step(0.0, d1);
    if (d2 > 1e2) { return vec2f(d1, h_rim); }
    let e = 0.5 * (d2 - d1);
    let meet = clamp(1.0 - 0.5 * (d1 + d2) / (2.0 * w), 0.0, 1.0);
    var axis = normalize(c2 - c1);
    // The same way for both holes, so the beads line up across the ridge.
    if (axis.x < 0.0) { axis = -axis; }
    let along = dot(x - 0.5 * (c1 + c2), vec2f(-axis.y, axis.x));
    let lambda = 6.5 * w;
    let k = along / lambda + s1 + s2;
    let db = length(vec2f(e, (fract(k) - 0.5) * lambda));
    let beading = smoothstep(0.4, 0.62, p);
    let dry = 1.0 - smoothstep(0.62, 0.97, p);
    let wr = w * sqrt(meet) * (1.0 - beading);
    let rb = 1.55 * w * smoothstep(0.0, 1.0, beading) * dry;
    let h_ridge = sqrt(max(wr * wr - e * e, 0.0));
    let h_bead = sqrt(max(rb * rb - db * db, 0.0));
    let inside = max(d1, max(select(-1.0, wr - e, wr > 0.0), select(-1.0, rb - db, rb > 0.0)));
    return vec2f(inside, max(h_rim, max(h_ridge, h_bead)));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let gloss = params.gloss;
    let p = progress;
    let asp = vec2f(ratio, 1.0);
    let x = uv * asp;
    let lq = liquid(x, p);
    let px = 0.0015;
    let cover = clamp(lq.x / px + 0.5, 0.0, 1.0);
    var to = to_color(uv);
    to = vec4f(to.rgb * (1.0 - 0.18 * gloss * (1.0 - smoothstep(0.8, 0.98, p)) * (1.0 - smoothstep(0.0, 0.012, -lq.x)) * step(lq.x, 0.0)), to.a);
    if (cover <= 0.0) { return to; }

    let eps = 0.002;
    var g = vec2f(liquid(x + vec2f(eps, 0.0), p).y - lq.y, liquid(x + vec2f(0.0, eps), p).y - lq.y) / eps;
    g = clamp(g, vec2f(-6.0), vec2f(6.0));
    let n = normalize(vec3f(-g, 1.0));
    let off = g * lq.y * 0.5 * gloss;
    let img = from_color(fold((x + off) / asp));
    let light = normalize(vec3f(-0.45, 0.55, 0.7));
    let hv = normalize(light + vec3f(0.0, 0.0, 1.0));
    let diffuse = dot(n, light) - light.z;
    let spec = max(pow(max(dot(n, hv), 0.0), 60.0) - pow(hv.z, 60.0), 0.0);
    let side = pow(1.0 - n.z, 3.0);
    var c = img.rgb * (1.0 + 0.45 * gloss * diffuse) * (1.0 - 0.5 * gloss * side) + gloss * spec;
    c *= 1.0 - 0.35 * gloss * (1.0 - smoothstep(0.0, 0.004, lq.x));
    return mix(to, vec4f(c, img.a), cover);
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
