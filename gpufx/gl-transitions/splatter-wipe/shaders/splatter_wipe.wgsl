// Port of SplatterWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SplatterWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const SPIKES: f32 = 14.0;
// Furthest reach of the shapes of a splat from its center, in cells. Splats are looked for in the
// 3x3 cells around a pixel, and the center of a splat 2 cells away is more than 1.35 cells away,
// which leaves a margin so that no splat is ever cut by the search.
const REACH: f32 = 1.25;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(v.xyx * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn modf_(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

// Smooth noise around a splat, wrapping over a full turn (t in 0..1).
fn turn_noise(t: f32, n: f32, key: vec2f) -> f32 {
    let x = t * n;
    let i = floor(x);
    let f = x - i;
    let a = hash12(key + vec2f(modf_(i, n), 61.0));
    let b = hash12(key + vec2f(modf_(i + 1.0, n), 61.0));
    return mix(a, b, f * f * (3.0 - 2.0 * f));
}

fn smax(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * k * 0.25;
}

// Signed distance (approximately, in cells, > 0 inside) to the splat of a grid cell.
fn splat(q: vec2f, cell: vec2f, key: vec2f, progress: f32) -> f32 {
    let t0 = 0.01 + 0.6 * hash12(key + vec2f(3.0, 0.0));
    if (progress <= t0) { return -1.0; }
    let c = cell + 0.5 + 0.3 * (vec2f(hash12(key + vec2f(5.0, 1.0)), hash12(key + vec2f(9.0, 2.0))) - 0.5);
    let d = q - c;
    let l = length(d);
    // Nothing of the splat reaches this far.
    if (l > REACH + 0.1) { return -1.0; }
    var pop = clamp((progress - t0) / 0.08, 0.0, 1.0);
    pop = 1.0 - (1.0 - pop) * (1.0 - pop) * (1.0 - pop);
    let x = clamp((progress - t0) / (0.96 - t0), 0.0, 1.0);
    let grow = x * x * x;
    let r0 = 0.42 + 0.2 * hash12(key + vec2f(11.0, 3.0));
    // The farthest corner of the cell is at most ~0.92 cells away; the body dents by 6% at most in the end.
    let rc = mix(r0 * pop, 1.03, grow);

    var a = 0.0;
    if (l > 1e-5) { a = atan2(d.y, d.x) / (2.0 * PI) + 0.5; }
    let lumps = mix(0.3, 0.06, grow) * (turn_noise(a, 5.0, key) - 0.5) + mix(0.18, 0.06, grow) * (turn_noise(a, 19.0, key + 3.0) - 0.5);
    var f = rc * (1.0 + lumps) - l;

    // A spike in each slice of the turn: a ray that tapers from a wide base, the long ones ending
    // in a bead; the slices on both sides are looked at too, as their spikes can lean over.
    let s = floor(a * SPIKES);
    var spike = -1.0;
    for (var k = -1; k <= 1; k++) {
        let sl = s + f32(k);
        let sk = key + vec2f(modf_(sl, SPIKES), 17.0);
        let h = hash12(sk);
        let w0 = (0.022 + 0.03 * hash12(sk + 1.5)) * pop;
        let len = max(min(params.spikiness * (0.06 + 0.6 * h * h) * pop, REACH - 1.2 * w0 - rc), 0.0);
        if (len > 0.0) {
            // Short spikes are thin too, so that no spikiness leaves a clean body.
            let w = w0 * min(len / 0.06, 1.0);
            let ang = (sl + 0.5 + 0.4 * (hash12(sk + 0.5) - 0.5)) / SPIKES * 2.0 * PI - PI;
            let dir = vec2f(cos(ang), sin(ang));
            let along = dot(d, dir);
            let across = abs(d.x * dir.y - d.y * dir.x);
            let u = clamp((along - rc) / len, 0.0, 1.0);
            var ray = min(w * (1.0 - 0.7 * u) - across, rc + len - along);
            if (h > 0.5) { ray = max(ray, w * 1.2 - length(d - dir * (rc + len))); }
            spike = max(spike, ray);
        }
    }
    f = smax(f, spike, 0.08);

    for (var j = 0; j < 5; j++) {
        let dk = key + vec2f(f32(j), 29.0);
        let hr = hash12(dk + 0.5);
        let rad = (0.015 + 0.05 * hr * hr) * clamp(params.droplets * 5.0 - f32(j), 0.0, 1.0) * pop;
        if (rad > 0.0) {
            let da = 2.0 * PI * hash12(dk);
            let dist = min(r0 + 0.08 + 0.5 * hash12(dk + 1.5), REACH - rad) * mix(0.5, 1.0, pop);
            f = max(f, rad - length(d - dist * vec2f(cos(da), sin(da))));
        }
    }

    if (params.drips > 0.0) {
        var run = clamp((progress - t0 - 0.03) / 0.45, 0.0, 1.0);
        run = run * (2.0 - run);
        for (var j = 0; j < 2; j++) {
            let dk = key + vec2f(f32(j), 43.0);
            let xo = (hash12(dk) - 0.5) * r0;
            let dw = (0.03 + 0.02 * hash12(dk + 0.5)) * pop;
            let top = sqrt(r0 * r0 - xo * xo) * pop;
            let bottom = min(top + params.drips * (0.25 + 0.75 * hash12(dk + 1.5)) * run, sqrt(REACH * REACH - xo * xo) - 1.6 * dw);
            let dx = abs(d.x - xo);
            let drip = min(dw - dx, min(d.y + bottom, -d.y));
            let tip = dw * 1.4 - length(vec2f(dx, d.y + bottom + 0.2 * dw));
            f = smax(f, max(drip, tip), 0.05);
        }
    }
    return f;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = max(1.0, floor(params.splats + 0.5));
    let cell_size = max(ratio, 1.0) / n;
    let q = vec2f(uv.x * ratio, uv.y) / cell_size; // in cells
    let base = floor(q);
    let sd = params.seed * vec2f(7.0, 13.0);
    var f = -1.0;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let cell = base + vec2f(f32(i), f32(j));
            f = max(f, splat(q, cell, cell + sd, progress));
        }
    }
    let aa = 0.0025 / cell_size; // about a pixel or two, in cells
    let covered = smoothstep(-aa, aa, f);
    let a = from_color(uv);
    let b = to_color(uv);
    let e = clamp(f / 0.045, 0.0, 1.0);
    let amount = params.rim * (1.0 - smoothstep(0.75, 1.0, progress));
    let dark = (1.0 - e) * (1.0 - e) * 0.6;
    let gloss = smoothstep(0.2, 0.4, e) * (1.0 - smoothstep(0.4, 0.7, e)) * 0.3;
    let to = vec4f(mix(b.rgb * (1.0 - dark * amount), vec3f(1.0), gloss * amount * b.a), b.a);
    return mix(a, to, covered);
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
