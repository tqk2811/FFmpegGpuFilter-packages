// Port of Whittle.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Whittle.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0018;
const SCORE_TIME: f32 = 0.075;
const LIFT: f32 = 0.025;
const GAP: f32 = 0.012;
const SHADOW_OFFSET: vec2f = vec2f(0.014, -0.022);
const SHADOW_BLUR: f32 = 0.03;

// Golden-angle steps spread the cut directions evenly whatever their number.
fn normal_of(k: f32) -> vec2f {
    let a = k * 2.39996 + 0.7;
    return vec2f(cos(a), sin(a));
}

// Offsets shrink so every cut still crosses what is left.
fn offset_of(k: f32, n: f32, r: f32) -> f32 {
    return 0.42 * r * (0.35 + 0.65 * (1.0 - k / n)) * (0.8 + 0.2 * fract(k * 0.618));
}

fn box_distance(q: vec2f, ratio: f32) -> f32 {
    let d = abs(q) - 0.5 * vec2f(ratio, 1.0);
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

// Signed distance to piece k (q relative to the center), negative inside; piece nc is the last polygon.
fn piece_distance(q: vec2f, k: i32, nc: i32, n: f32, r: f32, ratio: f32) -> f32 {
    var sd = box_distance(q, ratio);
    for (var m = 0; m < 6; m++) {
        if (m >= k) { break; }
        let fm = f32(m);
        sd = max(sd, dot(q, normal_of(fm)) - offset_of(fm, n, r));
    }
    if (k < nc) { sd = max(sd, offset_of(f32(k), n, r) - dot(q, normal_of(f32(k)))); }
    return sd;
}

fn slide_dir(k: f32, nk: vec2f) -> vec2f {
    return vec2f(-nk.y, nk.x) * select(-1.0, 1.0, k - 2.0 * floor(k / 2.0) < 0.5);
}

fn start_of(k: f32, n: f32) -> f32 { return 0.08 + k * 0.92 / (n + 2.2); }

fn slide_of(k: f32, n: f32, progress: f32) -> f32 {
    return clamp((progress - start_of(k, n)) * (n + 2.2) / (0.92 * 2.2), 0.0, 1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let nc = clamp(params.cuts, 2, 6);
    let n = f32(nc);
    let r = min(ratio, 1.0) + 0.25 * abs(ratio - 1.0);
    // Just enough to clear the frame with the shadow.
    let travel = length(vec2f(ratio, 1.0)) + 0.1;
    var c = to_color(uv);
    for (var k = 6; k >= 0; k--) {
        if (k > nc) { continue; }
        let fk = f32(k);
        let last = k == nc;
        let nk = normal_of(select(fk, fk - 1.0, last));
        let dk = slide_dir(fk, nk);
        let g = slide_of(fk, n, progress);
        if (g >= 1.0) { continue; }
        let lift = smoothstep(0.0, 0.35, g);
        let shift = dk * travel * g * g * g + select(nk * GAP * lift, vec2f(0.0), last);
        let scale = 1.0 + LIFT * lift * (1.0 - g);
        let q = (p - shift) / scale;
        let sp = (p - shift - SHADOW_OFFSET * lift) / scale;
        if (lift > 0.0) {
            let blur = SHADOW_BLUR * (0.3 + lift);
            let sh = lift * (1.0 - smoothstep(-blur, blur, piece_distance(sp, k, nc, n, r, ratio)));
            c = vec4f(mix(c.rgb, params.shadow.rgb, params.shadow.a * sh), c.a);
        }
        // Overhang by AA: while pieces still touch, overlapping edges sample the same pixel.
        let cover = clamp(0.5 - (piece_distance(q, k, nc, n, r, ratio) - AA) / AA, 0.0, 1.0);
        if (cover <= 0.0) { continue; }
        var col = from_color(clamp(q / vec2f(ratio, 1.0) + 0.5, vec2f(0.0), vec2f(1.0)));
        for (var m = 0; m < 6; m++) {
            if (m > k || m >= nc) { break; }
            let fm = f32(m);
            let nm = normal_of(fm);
            let dm = slide_dir(fm, nm);
            let run = clamp((progress - start_of(fm, n) + SCORE_TIME) / SCORE_TIME, 0.0, 1.0);
            let head = mix(-1.0, 1.0, run) * (0.5 * dot(abs(dm), vec2f(ratio, 1.0)) + 0.02);
            let behind = head - dot(q, dm);
            let drawn = clamp(0.5 + behind / AA, 0.0, 1.0) * (1.0 - smoothstep(0.0, 0.25, slide_of(fm, n, progress)));
            let e = abs(dot(q, nm) - offset_of(fm, n, r));
            let line = exp(-e / 0.0016) + 0.3 * exp(-e / 0.008);
            let tip = exp(-length(vec2f(behind, e)) / 0.012) * min(run * 20.0, 1.0) * (1.0 - run);
            let amount = clamp(params.score.a * drawn * (line * (0.6 + 0.4 * exp(-max(behind, 0.0) * 3.0)) + tip), 0.0, 1.0);
            col = vec4f(mix(col.rgb, params.score.rgb, amount), col.a);
        }
        c = mix(c, col, cover);
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
