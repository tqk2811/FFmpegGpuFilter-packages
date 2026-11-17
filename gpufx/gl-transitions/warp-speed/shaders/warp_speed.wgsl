// Port of WarpSpeed.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WarpSpeed.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const TAPS: i32 = 12;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// One layer of stars: one per angular cell, flying outward and stretched along its ray.
fn stars(a: f32, r: f32, n: f32, layer: f32, travel: f32, speed: f32, reach: f32) -> f32 {
    let cell = floor(a * n);
    let h1 = hash(vec2f(cell, layer));
    let h2 = hash(vec2f(cell, layer + 17.0));
    let h3 = hash(vec2f(cell, layer + 31.0));
    let life = fract(h1 + travel * (0.6 + 0.8 * h2));
    let head = reach * (0.05 + 1.05 * pow(life, 1.4));
    let tail = head * (1.0 - min(0.9, speed * (0.15 + 0.5 * h3)));
    let along = clamp((r - tail) / max(head - tail, 1e-4), 0.0, 1.0);
    let inside = step(tail, r) * (1.0 - smoothstep(head - 0.006, head, r));
    let profile = inside * along * along;
    // Thin across the ray, faded out before the cell edges so no seam shows.
    let f = fract(a * n);
    let cell_width = 2.0 * PI * r / n;
    let across = (f - (0.3 + 0.4 * h3)) * cell_width;
    let width = min(0.0014 + 0.002 * r / reach, 0.15 * cell_width);
    let x = across * across / (width * width);
    let line = (exp(-x) + 0.25 * exp(-x / 9.0)) * smoothstep(0.0, 0.2, min(f, 1.0 - f));
    let fade = smoothstep(0.0, 0.2, life) * (1.0 - smoothstep(0.9, 1.0, life));
    return profile * line * fade * (0.4 + 0.6 * h2) * step(0.25, hash(vec2f(cell, layer + 43.0)));
}

// A clip pulled into a radial smear toward the center: scaled by k, blurred over a fraction b.
fn smear(uv: vec2f, center: vec2f, k: f32, b: f32, jitter: f32, incoming: bool) -> vec4f {
    if (b <= 0.0 && k >= 1.0) {
        let c = select(from_color(uv), to_color(uv), incoming);
        return vec4f(c.rgb * c.a, c.a);
    }
    var sum = vec4f(0.0);
    for (var i = 0; i < TAPS; i++) {
        let s = k * (1.0 - b * (f32(i) + jitter) / f32(TAPS));
        let q = center + (uv - center) * s;
        let c = select(from_color(q), to_color(q), incoming);
        sum += vec4f(c.rgb * c.a, c.a);
    }
    return sum / f32(TAPS);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let strength = params.strength;
    // `center` is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let p = progress;
    let aspect = vec2f(ratio, 1.0);
    let d = (uv - center) * aspect;
    let r = length(d);
    let a = atan2(d.y, d.x + 1e-6) / (2.0 * PI) + 0.5;
    let reach = length(max(center, 1.0 - center) * aspect);
    var speed = sin(PI * p);
    speed *= speed;
    let travel = 3.0 * (p - sin(2.0 * PI * p) / (2.0 * PI));
    let jitter = hash(floor(uv * aspect * 997.0));
    let go_out = smoothstep(0.0, 0.55, p);
    let go_in = 1.0 - smoothstep(0.45, 1.0, p);
    let soft = 0.35 * reach;
    let edge = mix(-soft, reach + soft, smoothstep(0.42, 0.78, p));
    let m = 1.0 - smoothstep(edge - soft, edge, r);
    var before = vec4f(0.0);
    var after = vec4f(0.0);
    if (m < 1.0) { before = smear(uv, center, 1.0 - 0.3 * strength * go_out * go_out, 0.6 * strength * go_out, jitter, false); }
    if (m > 0.0) { after = smear(uv, center, 1.0 - 0.3 * strength * go_in * go_in, 0.6 * strength * go_in, jitter, true); }
    var c = mix(before, after, m);
    let dark = select(speed * speed * speed, speed, p < 0.5);
    c = vec4f(c.rgb * (1.0 - 0.65 * (0.5 + 0.5 * strength) * dark), c.a);
    let n = max(floor(params.streaks), 1.0);
    let len = speed * (0.5 + 1.5 * strength);
    var s = stars(a, r, n, 1.0, travel, len, reach);
    s += stars(fract(a + 0.37), r, max(floor(n * 0.71), 1.0), 2.0, travel * 1.3, len, reach);
    let core = r / (0.35 * reach);
    let peak = (p - 0.5) * 9.0;
    let glow = params.flash * exp(-peak * peak) * speed * (0.35 + 0.9 * exp(-core * core));
    let light = params.streak_color.rgb * params.streak_color.a * (2.2 * s * speed + glow);
    // Light is added to the picture, but adds no opacity.
    if (c.a > 0.0) { return vec4f(clamp(c.rgb / c.a + light, vec3f(0.0), vec3f(1.0)), c.a); }
    return vec4f(0.0);
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
