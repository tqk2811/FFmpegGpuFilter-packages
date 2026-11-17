// Port of GooeyWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GooeyWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn fold(p: vec2f) -> vec2f { return 1.0 - abs(1.0 - (p - 2.0 * floor(p / 2.0))); }

// Signed distance to the blob of a grid cell (in cells), its center returned in .yz.
fn blob(cell: vec2f, r_start: f32, r_end: f32, progress: f32) -> vec3f {
    let c = cell + 0.5 + 0.7 * (vec2f(hash(cell + 0.5), hash(cell + 41.3)) - 0.5);
    let t0 = 0.02 + 0.43 * hash(cell + 17.9);
    let s = clamp((progress - t0) / (1.0 - t0), 0.0, 1.0);
    var pop = clamp((progress - t0) / 0.12, 0.0, 1.0);
    pop = 1.0 - (1.0 - pop) * (1.0 - pop) * (1.0 - pop);
    var r = mix(r_start, 0.18, pop) + (r_end - 0.18) * s * sqrt(s);
    r += 0.05 * sin(pop * 9.0) * (1.0 - s) * pop;
    return vec3f(r, c);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = max(1.0, floor(params.blobs + 0.5));
    let cell_size = max(ratio, 1.0) / n;
    let q = vec2f(uv.x * ratio, uv.y) / cell_size;
    let base = floor(q);
    // Melting distance and width of the rounded rim, in cells.
    let k = 0.02 + 0.25 * params.smoothness;
    let w = 0.16;
    // A blob starts far enough below the surface not to show, and ends up covering its whole cell and its rim.
    let r_start = -(0.03 + 4.0 * k);
    let r_end = 0.85 * sqrt(2.0) + w + 0.05;
    // Smooth union (log-sum-exp, computed online) of the blobs around, with its gradient.
    var m = 1e3;
    var sum = 0.0;
    var grad = vec2f(0.0);
    var r_near = 0.0;
    for (var j = -3; j <= 3; j++) {
        for (var i = -3; i <= 3; i++) {
            let b = blob(base + vec2f(f32(i), f32(j)), r_start, r_end, progress);
            let dq = q - b.yz;
            let l = length(dq);
            let dist = l - b.x;
            let g = dq / max(l, 1e-4);
            if (dist < m) {
                let scale = exp((dist - m) / k);
                sum = sum * scale + 1.0;
                grad = grad * scale + g;
                m = dist;
                r_near = b.x;
            } else {
                let wt = exp((m - dist) / k);
                sum += wt;
                grad += wt * g;
            }
        }
    }
    let d = m - k * log(sum); // < 0 inside the goo
    grad /= sum;
    let aa = 0.012 * n / 5.0;
    let inside = 1.0 - smoothstep(-aa, aa, d);
    let h = clamp(-d / w, 0.0, 1.0);
    let settle = 1.0 - smoothstep(0.45, 0.85, progress);
    let tilt = (1.0 - h) * (1.0 - h) * settle;
    let nrm = normalize(vec3f(grad * tilt * 3.0, 1.0));
    let halfway = normalize(vec3f(-0.35, 0.45, 1.0) + vec3f(0.0, 0.0, 1.0));
    let spec = pow(max(dot(nrm, halfway), 0.0), 200.0) * settle;
    let shade = 1.0 - tilt * (0.25 + 0.3 * clamp(dot(grad, vec2f(0.6, -0.8)) + 0.3, 0.0, 1.0));
    var to = to_color(fold(uv - grad * tilt * 0.01 * cell_size / vec2f(ratio, 1.0)));
    let t2 = tilt * tilt;
    let gloss = 0.3 * t2 * t2;
    to = vec4f(mix(to.rgb * shade, params.highlight.rgb, clamp(spec + gloss, 0.0, 1.0) * params.highlight.a), to.a);
    var fr = from_color(uv);
    let sh = params.shadow.a * (1.0 - smoothstep(0.0, 0.15, d + 0.03)) * smoothstep(0.0, 0.3, r_near);
    fr = vec4f(mix(fr.rgb, params.shadow.rgb, sh), fr.a);
    return mix(fr, to, inside);
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
