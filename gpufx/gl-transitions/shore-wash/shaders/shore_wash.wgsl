// Port of ShoreWash.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ShoreWash.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.002;
// How far the lobes of the front lead or trail, in frame heights.
const LOBE: f32 = 0.06;
const LACE: f32 = 0.3;
const CELL: f32 = 0.045;
// Part of the transition the water runs up during; it drains back during the rest.
const RUNUP: f32 = 0.4;
const FOAMW: f32 = 0.1;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn hash22(p: vec2f) -> vec2f {
    var p3 = fract(vec3f(p.x, p.y, p.x) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

fn vnoise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
        mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

// Foam: bubbles packed side by side, white where they touch and open at their centers. Sparse
// foam is a faint lace; the denser it is, the brighter it is and the smaller the holes, until
// they close (density 1).
fn bubbles(p: vec2f, density: f32) -> f32 {
    let i = floor(p);
    let f = fract(p);
    var d1 = 8.0;
    var d2 = 8.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let o = vec2f(f32(x), f32(y));
            let c = o + 0.15 + 0.7 * hash22(i + o) - f;
            let d = dot(c, c);
            if (d < d1) {
                d2 = d1;
                d1 = d;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    let e = sqrt(d2) - sqrt(d1);
    let w = 0.12 + 0.6 * density;
    return (1.0 - smoothstep(w - 0.12, w + 0.12, e)) * smoothstep(0.0, 0.35, density);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dir = vec2f(0.0, 1.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    // Distance along the run-up, 0 at the middle of the frame, and across it.
    let a = dot(q, dir);
    let b = dot(q, vec2f(-dir.y, dir.x));
    let extent = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let start = -extent - LOBE - 0.1;
    let stop = extent + LOBE + 0.01;

    let up = clamp(progress / RUNUP, 0.0, 1.0);
    let back = clamp((progress - RUNUP) / (1.0 - RUNUP), 0.0, 1.0);
    let front = mix(start, stop, 1.0 - pow(1.0 - up, 1.6)) - (stop - start) * pow(back, 1.5);

    let lobes = vnoise(vec2f(b * 7.0 + 3.1, progress * 2.0)) * 0.7 + vnoise(vec2f(b * 17.0, 5.0 + progress * 3.0)) * 0.3;
    let behind = front + LOBE * (lobes - 0.5) * 2.0 - a; // > 0 under the water
    let sheet = smoothstep(-AA, AA, behind);

    // The clips swap under the dense foam right behind the running front, and finish swapping
    // under the water as it stops by the far edge.
    let swapped = max(smoothstep(0.01, 0.8 * FOAMW, behind), select(1.0, sheet, progress < RUNUP) * smoothstep(RUNUP - 0.08, RUNUP, progress));

    let rp = vec2f(a * 20.0, b * 5.0 + 3.0 * vnoise(q * 4.0)) - vec2f(7.0 * min(progress, RUNUP) - 5.0 * back, 0.0);
    let n0 = vnoise(rp);
    let g = (vnoise(rp + vec2f(0.15, 0.0)) - n0) / 0.15 * dir + (vnoise(rp + vec2f(0.0, 0.15)) - n0) / 0.15 * vec2f(-dir.y, dir.x);
    let thick = sheet * smoothstep(0.0, 0.12, behind);
    let off = g * params.refraction * thick * vec2f(1.0 / ratio, 1.0);

    let c0 = mix(from_color(mirror(uv + off)), to_color(mirror(uv + off)), swapped);
    var rgb = mix(c0.rgb, params.water.rgb, params.water.a * sheet * (0.3 + 0.7 * smoothstep(0.0, 0.35, behind)));
    let glint = pow(max(dot(normalize(vec3f(-g, 3.0)), normalize(vec3f(-0.3, 0.6, 1.0))), 0.0), 14.0);
    rgb += glint * 0.4 * thick;

    let wet = (1.0 - sheet) * exp(min(behind, 0.0) * 2.5) * smoothstep(RUNUP, RUNUP + 0.05, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
    rgb *= mix(vec3f(1.0), rgb, 0.55 * wet);
    rgb += 0.1 * wet * smoothstep(0.4, 0.9, vnoise(vec2f(a * 30.0, b * 6.0)));

    let lp = vec2f(a - 0.4 * select(stop, front, progress < RUNUP), b) / CELL;
    let patches = smoothstep(0.45, 0.8, 0.6 * vnoise(lp * vec2f(0.4, 0.1) + 4.0) + 0.4 * vnoise(lp * 0.3 + 9.0));
    let band_w = FOAMW * (0.5 + vnoise(vec2f(b * 25.0, 2.0)));
    var density = (1.0 - smoothstep(0.0, band_w, behind)) * (1.0 - smoothstep(RUNUP - 0.05, RUNUP + 0.12, progress));
    density = max(density, 0.55 * patches * (1.0 - smoothstep(0.0, LACE, behind)) * (1.0 - 0.5 * back));
    density = max(density, 0.9 * (1.0 - smoothstep(0.0, 0.012 + 0.02 * vnoise(vec2f(b * 40.0, 1.0)), behind)));
    density *= sheet;
    var f = 0.0;
    if (density > 0.0) {
        f = max(bubbles(lp, density), 0.85 * bubbles(lp * 1.7 + 7.0, density * 0.9));
        f = max(f, 0.45 * smoothstep(0.15, 0.7, density)) * params.foam;
    }
    rgb *= 1.0 - 0.25 * sheet * params.foam * (1.0 - f) * smoothstep(0.0, 0.6, density);
    rgb = mix(rgb, vec3f(0.97, 0.98, 0.97), clamp(f, 0.0, 1.0));
    let sh = smoothstep(-0.03, 0.0, behind);
    rgb *= 1.0 - 0.35 * (1.0 - sheet) * sh * sh * (1.0 - smoothstep(RUNUP - 0.05, RUNUP, progress));
    return vec4f(rgb, c0.a);
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
