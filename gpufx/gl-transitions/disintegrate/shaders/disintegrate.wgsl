// Port of Disintegrate.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Disintegrate.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The grains a pixel looks back to, along the wind: every grain up to 16 cells away, one in 2 up
// to 32 cells, one in 4 up to 64 cells (only those stay visible that far, so the dust thins out as
// it flies): 35 candidates.
const NEAR: i32 = 17;
const CANDIDATES: i32 = 35;
const LIFE: f32 = 0.45;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn modf_(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn noise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    let a = hash12(i);
    let b = hash12(i + vec2f(1.0, 0.0));
    let c = hash12(i + vec2f(0.0, 1.0));
    let d = hash12(i + vec2f(1.0, 1.0));
    return 2.0 * mix(mix(a, b, f.x), mix(c, d, f.x), f.y) - 1.0;
}

// The grains' sideways drift, in gusts along the wind, between -1 and 1: it depends only on where
// a grain comes from along the wind, so that a pixel knows which row to look in.
fn gust(x: f32) -> f32 {
    let i = floor(x);
    var f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return 2.0 * mix(hash12(vec2f(i, 7.0)), hash12(vec2f(i + 1.0, 7.0)), f) - 1.0;
}

// When the grain at center (in cells) is released: downwind side first, along a ragged front.
fn release(center: vec2f, h: f32, half_length: f32, s: f32) -> f32 {
    let front = 1.0 - (center.x + half_length) / (2.0 * half_length) + 0.14 * noise(center * s * 6.0) + 0.08 * (h - 0.5);
    return clamp((front + 0.12) / 1.24, 0.0, 1.0) * (1.0 - LIFE);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var d = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { d = normalize(params.direction); }
    let n = vec2f(-d.y, d.x);
    let fp = (uv - 0.5) * vec2f(ratio, 1.0);
    let s = params.particle_size;
    let g = vec2f(dot(fp, d), dot(fp, n)) / s;
    let half_length = 0.5 * (ratio * abs(d.x) + abs(d.y)) / s;
    // The longest flight, in cells (at most 60, within the 64 cells looked back to).
    let reach = min(params.spread * 0.45 / s, 60.0);
    let px = floor(g.x);

    let own = floor(g);
    var under = from_color(uv);
    if (progress > release(own + 0.5, hash12(own), half_length, s)) { under = to_color(uv); }
    var grain_uv = vec2f(0.5);
    var cover = 0.0;
    for (var i = 0; i < CANDIDATES; i++) {
        let fi = f32(i);
        var cx = px - fi;
        if (i >= NEAR + 9) {
            cx = floor(px / 4.0) * 4.0 - 4.0 * (fi - f32(NEAR + 9) + 8.0);
        } else if (i >= NEAR) {
            cx = floor(px / 2.0) * 2.0 - 2.0 * (fi - f32(NEAR) + 8.0);
        }
        // How far the grain stays visible (in cells): further when its column is a multiple of 2,
        // and of 4, as far as the pixels look back to.
        var visible = 15.0;
        if (modf_(cx, 4.0) < 0.5) { visible = 63.0; } else if (modf_(cx, 2.0) < 0.5) { visible = 31.0; }
        let drift = 0.3 * gust(cx * s * 4.0);
        // The row the grain comes from: its sideways drift is known from its column and how far it
        // has flown to get here.
        let cell = vec2f(cx, floor(g.y - drift * (g.x - cx - 0.5)));
        let center = cell + 0.5;
        let cuv = (center.x * d + center.y * n) * s / vec2f(ratio, 1.0) + 0.5;
        if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) { continue; }
        let h = hash12(cell);
        let t = (progress - release(center, h, half_length, s)) / LIFE;
        if (t <= 0.0 || t >= 1.0) { continue; }
        let r2 = fract(h * 13.7);
        let travel = reach * (0.4 + 0.6 * r2) * t * (0.2 + 0.8 * t);
        let crumble = smoothstep(0.0, 0.25, t);
        let pos = center + vec2f(travel + (fract(h * 71.1) - 0.5) * 0.3 * crumble, drift * travel);
        let local = abs(g - pos);
        let size = mix(0.5, 0.3 * (1.0 - 0.5 * t) * (0.6 + 0.4 * h), crumble);
        let feather = 0.001 + 0.12 * crumble;
        let a = (1.0 - smoothstep(size - feather, size, max(local.x, local.y))) * (1.0 - smoothstep(0.15, 1.0, t))
            * (1.0 - smoothstep(0.6 * visible, visible, travel));
        if (a > cover) {
            cover = a;
            grain_uv = cuv;
        }
    }
    return mix(under, from_color(grain_uv), cover);
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
