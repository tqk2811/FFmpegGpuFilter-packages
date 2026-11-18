// Port of VhsTracking.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/VhsTracking.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const LINES: f32 = 220.0; // tape lines over the frame height
const FRAMES: f32 = 40.0; // the noise changes this many times over the transition
const BAND: f32 = 0.11;
const STRIP: f32 = 0.06;
const TAPS: i32 = 6;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(v.xyx * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

// The tape picture of the first (or, once re-recorded, second) clip, premultiplied.
fn tape(p0: vec2f, fresh: bool) -> vec4f {
    let p = mirror(p0);
    var c = from_color(p);
    if (fresh) { c = to_color(p); }
    return vec4f(c.rgb * c.a, c.a);
}

fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.299, 0.587, 0.114));
}

// How dense a band centered at y = c of half height w is on line y, with ragged edges.
fn band_density(y: f32, c: f32, w: f32, jitter: f32) -> f32 {
    let d = abs(y - c) / w + 0.35 * jitter;
    return 1.0 - smoothstep(0.0, 1.0, d);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let noise = params.noise;
    // The effects build up quickly and settle at the end: exactly 0 at both ends.
    let h = clamp(2.5 * (1.0 - abs(2.0 * progress - 1.0)), 0.0, 1.0);
    let env = h * h * (3.0 - 2.0 * h);
    let f = clamp(1.0 - abs(progress - 0.5) / 0.04, 0.0, 1.0);
    let flash = f * f * (3.0 - 2.0 * f);

    let frame = floor(progress * FRAMES);
    let line = floor(uv.y * LINES);
    let jitter = hash12(vec2f(line, frame + 7.0)) - 0.5;

    // The main band rolls from above the frame to below it; the second clip is above it.
    let c0 = mix(1.0 + 1.2 * BAND, -1.2 * BAND, progress);
    let fresh = uv.y > c0 + 0.8 * BAND * jitter;
    var dens = band_density(uv.y, c0, BAND, jitter);
    var tear = 1.0 - smoothstep(0.0, 1.0, abs(uv.y - c0) / (2.5 * BAND));
    for (var i = 1; i < 4; i++) {
        if (i < params.bands) {
            let k = f32(i);
            let w = BAND * (0.35 + 0.2 * hash12(vec2f(k, 3.0)));
            let speed = 1.3 + 0.9 * k;
            let cy = -w + (1.0 + 2.0 * w) * fract(hash12(vec2f(k, 5.0)) - speed * progress);
            dens = max(dens, 0.6 * band_density(uv.y, cy, w, jitter));
            tear = max(tear, 0.5 * (1.0 - smoothstep(0.0, 1.0, abs(uv.y - cy) / (2.5 * w))));
        }
    }
    dens *= env;
    tear *= env;

    let row_tear = hash12(vec2f(floor(uv.y * LINES * 0.5), frame + 31.0)) - 0.5;
    var dx = params.wobble * env * (0.006 * sin(uv.y * 7.0 + progress * 23.0) + 0.004 * jitter);
    dx += (0.3 + 0.7 * noise) * tear * 0.18 * row_tear;
    let strip = env * (1.0 - smoothstep(0.0, STRIP, uv.y));
    dx += strip * (0.03 + 0.06 * (1.0 - uv.y / STRIP)) * (0.6 + 0.8 * hash12(vec2f(frame, 41.0)));
    let q = vec2f(uv.x + dx, uv.y);

    let c = tape(q, fresh);
    if (c.a <= 0.0) { return vec4f(0.0); }
    let len = params.bleed * (0.02 + 0.05 * dens) * env;
    var avg = c;
    if (len > 0.0) {
        avg = vec4f(0.0);
        for (var i = 0; i < TAPS; i++) {
            let u = (f32(i) + 0.5) / f32(TAPS);
            avg += tape(q - vec2f(len * (0.4 + u), 0.0), fresh);
        }
        avg /= f32(TAPS);
    }
    let chroma = (avg.rgb - luma(avg.rgb)) / max(avg.a, 1e-5);
    var rgb = luma(c.rgb) + chroma * c.a; // premultiplied by c.a
    rgb = mix(rgb, vec3f(luma(rgb)), 0.6 * dens);

    // Snow: short white streaks on the tape lines, starting at a random offset on each line.
    let cell = vec2f(floor(uv.x * LINES * 0.3 * ratio + 40.0 * jitter), line);
    let n = hash12(cell + frame * vec2f(37.0, 17.0));
    let amount = clamp(noise * max(1.3 * dens, 0.8 * strip) + 0.35 * flash, 0.0, 1.0);
    var snow = 0.0;
    if (amount > 0.0) { snow = smoothstep(1.0 - amount, 1.0 - 0.6 * amount, n); }
    snow *= 0.55 + 0.45 * hash12(cell.yx + frame);
    let g = hash12(vec2f(floor(uv.x * LINES * ratio), line) + frame * vec2f(13.0, 29.0));
    if (amount > 0.0) { snow = max(snow, 0.7 * smoothstep(1.0 - 0.4 * amount, 1.0, g)); }
    var dark = 0.0;
    if (g < 0.1 * amount) { dark = min(10.0 * amount, 1.0); }
    let group = floor(uv.y * LINES / 3.0);
    let drop = step(1.0 - 0.15 * flash, hash12(vec2f(group, floor(uv.x * 6.0 + 5.0 * hash12(vec2f(group, frame))) + frame * 7.0)));
    rgb *= 1.0 - 0.5 * dark;
    snow *= min(10.0 * amount, 1.0);
    rgb += clamp(snow + drop + 0.12 * flash, 0.0, 1.0) * (c.a - rgb);

    return vec4f(clamp(rgb / c.a, vec3f(0.0), vec3f(1.0)), c.a);
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
