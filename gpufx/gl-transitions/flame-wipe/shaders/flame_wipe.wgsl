// Port of FlameWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FlameWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const BAND: f32 = 0.45;
const PAD: f32 = 0.3;
const RAGGED: f32 = 0.05;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn noise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = v - i;
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
               mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn fbm(v_in: vec2f) -> f32 {
    var v = v_in;
    var sum = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 4; i++) {
        sum += amp * noise(v);
        v = v * 2.03 + vec2f(17.3, 9.1);
        amp *= 0.5;
    }
    return sum / 0.9375;
}

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

fn fire(h: f32) -> vec3f {
    let color = params.color.rgb;
    var c = mix(vec3f(0.22, 0.01, 0.0), color * color * vec3f(1.0, 0.6, 0.4), smoothstep(0.0, 0.3, h));
    c = mix(c, color, smoothstep(0.25, 0.55, h));
    c = mix(c, vec3f(1.0, 0.8, 0.35), smoothstep(0.55, 0.8, h));
    return mix(c, vec3f(1.0, 0.96, 0.82), smoothstep(0.8, 1.0, h));
}

// Width of a flame tongue climbing along an upright line, from its base (s = 0) to its tip (s = 1).
fn climbing(s: f32, size: f32) -> f32 {
    return (0.42 + 0.56 * size) * 6.75 * s * (1.0 - s) * (1.0 - s);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let color = params.color.rgb;
    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 1e-5) { dir = normalize(params.direction); }
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let rise = params.height * dir.y;
    let w = 0.05 + 0.35 * params.height;
    let reach = w * (1.75 + 0.6 * abs(dir.x));
    // The front crosses the frame at the same pace whatever the height of the flames.
    let extent = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + PAD;
    let e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.3);
    let burn = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
    let scorch_amount = params.scorch * smoothstep(0.0, 0.2, progress);
    let glow_amount = params.glow * (1.0 - smoothstep(0.75, 1.0, progress));
    let t = progress * 5.0;
    let side = dot(q, vec2f(-dir.y, dir.x));
    let front = mix(-extent, extent, e) + RAGGED * (2.0 * noise(vec2f(side * 4.0, t * 0.4)) - 1.0);
    // > 0 ahead of the fire, on the first clip.
    let k = dot(q, dir) - front;
    var billow = noise(vec2f(q.x * 3.0 + 5.0, q.y * 2.5 - t * 1.6));
    let y = q.y * 3.0 - t * 1.4;
    let y2 = y + 0.5;
    let climb = max(climbing(fract(y), hash12(vec2f(floor(y), 3.0))),
                    climbing(fract(y2), hash12(vec2f(floor(y2), 7.0))));
    billow = mix(billow, 0.4 * billow + climb, abs(dir.x));
    let line_width = w * (0.25 + 1.5 * billow);
    let line = 1.0 - smoothstep(0.0, line_width, abs(k));
    var tongue = 0.0;
    if (abs(rise) > 1e-4) {
        let s = k / rise;
        if (s >= 0.0) { tongue = clamp(1.0 - s, 0.0, 1.0); }
    }
    let heat = max(line, tongue) * burn;
    let near = 1.0 - smoothstep(0.0, BAND, abs(k));
    let h = q * vec2f(9.0, 5.0) + vec2f(0.0, -t * 3.0);
    let shimmer = (vec2f(noise(h), noise(h + 31.7)) - 0.5) * 0.012 * min(near + heat, 1.0) * burn;
    var a = from_color(mirror(uv + shimmer));
    var b = to_color(uv);
    let brown = select(0.0, scorch_amount * near, k > 0.0);
    let lum = dot(a.rgb, vec3f(0.299, 0.587, 0.114));
    a = vec4f(mix(a.rgb, lum * vec3f(0.9, 0.55, 0.28), brown) * (1.0 - 0.35 * brown) * (1.0 - 0.9 * brown * near * near), a.a);
    let g = select(0.0, glow_amount * near, k < 0.0);
    b = vec4f(b.rgb * mix(vec3f(1.0), vec3f(1.0, 0.6, 0.35), 0.7 * g) + color * 0.4 * g * g, b.a);
    // Far from the fire, only one of the clips shows.
    if (k >= max(BAND, max(rise, reach))) { return select(vec4f(0.0), a, a.a > 0.0); }
    if (-k >= max(BAND, max(-rise, reach))) { return select(vec4f(0.0), b, b.a > 0.0); }
    let m = smoothstep(-0.5 * w, 0.5 * w, k);
    let c = mix(vec4f(b.rgb * b.a, b.a), vec4f(a.rgb * a.a, a.a), m);
    if (c.a <= 0.0) { return vec4f(0.0); }
    var col = c.rgb / c.a;
    let f = vec2f(q.x * mix(10.0, 6.0, abs(dir.x)), q.y * mix(1.8, 3.2, abs(dir.x)) - t * 2.4);
    let sway = fbm(vec2f(q.x * 2.5, q.y * 1.5 - t * 1.2));
    var n = fbm(f + vec2f(1.5 * sway - 0.75, 0.0));
    n = clamp(1.7 * n - 0.35, 0.0, 1.0);
    let core = (1.0 - smoothstep(0.0, 0.35 * line_width, abs(k + 0.4 * w * (sway - 0.5)))) * burn * (1.0 - 0.5 * abs(dir.x));
    var root = 0.0;
    if (rise > 0.0) { root = clamp(-k / w, 0.0, 1.0); } else if (rise < 0.0) { root = clamp(k / w, 0.0, 1.0); }
    root *= abs(dir.y);
    let flame = clamp(heat * 0.95 + 0.45 * core * (0.75 + 0.25 * n) - (1.0 - n) * 1.1 * (1.0 - 0.8 * root), 0.0, 1.0);
    // The flames darken what is behind them and add their light; the alpha stays the clip's.
    let body = smoothstep(0.0, 0.08 + 0.5 * root, flame);
    col = col * (1.0 - 0.7 * body) + fire(flame) * (0.45 + 0.65 * flame) * body;
    col += color * 0.25 * heat * heat * (1.0 - body);
    return vec4f(clamp(col, vec3f(0.0), vec3f(1.0)), c.a);
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
