// Port of ScreenPrintWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ScreenPrintWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// The four passes end here, then the layers settle into register and the dots melt into the picture.
const PRINTED: f32 = 0.8;
// Share of black taken out of the three colors (an exact separation, whatever the amount).
const BLACK: f32 = 0.6;
// Widths across the squeegee, in frame heights: bead of ink ahead of the blade, rubber blade, holder behind it.
const BEAD: f32 = 0.03;
const RUBBER: f32 = 0.009;
const HOLDER: f32 = 0.075;
const SHADOW: f32 = 0.018;
const SHADOW_SOFT: f32 = 0.02;
const AA: f32 = 0.0015;

fn fmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn sp_hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn sp_noise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(sp_hash(i), sp_hash(i + vec2f(1.0, 0.0)), f.x),
        mix(sp_hash(i + vec2f(0.0, 1.0)), sp_hash(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

// Mirrored coordinates, so that a shifted lookup never smears the frame's border.
fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// Amount of ink of pass i (yellow, magenta, cyan, black) separating the color c.
fn separation(c: vec3f, i: f32) -> f32 {
    let k = BLACK * (1.0 - max(max(c.r, c.g), c.b));
    if (i > 2.5) { return k; }
    let channel = select(select(c.r, c.g, i < 1.5), c.b, i < 0.5);
    return clamp((1.0 - channel - k) / (1.0 - k), 0.0, 1.0);
}

fn ink_filter(i: f32) -> vec3f {
    if (i < 0.5) { return vec3f(1.0, 1.0, 0.0); }
    if (i < 1.5) { return vec3f(1.0, 0.0, 1.0); }
    if (i < 2.5) { return vec3f(0.0, 1.0, 1.0); }
    return vec3f(0.0);
}

fn ink_color(i: f32) -> vec3f {
    if (i < 0.5) { return vec3f(1.0, 0.84, 0.05); }
    if (i < 1.5) { return vec3f(0.86, 0.06, 0.48); }
    if (i < 2.5) { return vec3f(0.0, 0.58, 0.86); }
    return vec3f(0.07, 0.07, 0.08);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let aspect = vec2f(ratio, 1.0);
    let p = (uv - 0.5) * aspect;
    let settle = smoothstep(PRINTED, 1.0, progress);
    let rough = clamp(params.grit, 0.0, 1.0) * (1.0 - settle);
    let cells = max(params.dots, 1.0);

    let fc = from_color(uv);
    let tc = to_color(uv);
    var col = fc.rgb;
    var alpha = fc.a;
    var shade = 1.0;
    var tool = vec4f(0.0);

    for (var n = 0; n < 4; n++) {
        let i = f32(n);
        let t = clamp((progress - i * PRINTED / 4.0) / (PRINTED / 4.0), 0.0, 1.0);
        // The passes run one after another: none of the next ones has started yet.
        if (t <= 0.0) { break; }
        let even = fmod(i, 2.0) < 0.5;
        let dir = select(-1.0, 1.0, even);
        let tilt = select(0.07, 0.05, even);
        let m = dir * p.x + tilt * p.y;
        let extent = 0.5 * ratio + 0.5 * abs(tilt);
        // The squeegee speeds up into the frame and slows down out of it, without stopping.
        let e = mix(t, t * t * (3.0 - 2.0 * t), 0.55);
        let front = mix(-extent - 1.15 * BEAD - SHADOW - SHADOW_SOFT, extent + HOLDER + SHADOW + SHADOW_SOFT, e);
        // Across the blade: u < 0 ahead of it, u > 0 behind it, v along it.
        let u = front - m;
        let v = dir * p.y - tilt * p.x;
        let cover = smoothstep(-AA, AA, u);

        let a = 2.4 * i + 0.7;
        let offset = params.misregistration * (1.0 - settle) * vec2f(cos(a), sin(a)) * (0.6 + 0.4 * fmod(i * 3.0, 4.0) / 3.0);
        let s = to_color(mirror(uv + offset / aspect));
        var amount = separation(s.rgb, i);
        var streak = sp_noise(vec2f(v * 90.0, m * 2.0 + i * 13.0));
        streak = smoothstep(0.3, 0.9, streak);
        let speck = step(sp_hash(floor(p * 260.0) + i * 17.3), 0.07 * rough);
        amount *= 1.0 - rough * (0.3 * streak + speck);
        let ga = radians(select(select(select(45.0, 15.0, i < 2.5), 75.0, i < 1.5), 0.0, i < 0.5));
        let g = vec2f(cos(ga) * p.x - sin(ga) * p.y, sin(ga) * p.x + cos(ga) * p.y) * cells;
        // A dot grows from each cell's center (and a hole shrinks at its corners past half): the ink covers
        // the part of the cell where the spot is below the level whose area matches the amount of ink.
        let cell = 2.0 * PI * fract(g);
        let spot = 0.5 - 0.25 * (cos(cell.x) + cos(cell.y));
        let d = 1.0 - 2.0 * amount;
        let level = 0.5 - 0.5 * sign(d) * pow(abs(d), 1.5);
        let w = 0.16;
        let dotted = smoothstep(-w, w, level * (1.0 + 2.0 * w) - w - spot);
        let c = mix(dotted, amount, settle) * mix(s.a, 1.0, settle);
        var ink = 1.0 - c * (1.0 - ink_filter(i));
        let wet = (1.0 - smoothstep(0.75, 1.0, t)) * exp(-max(u, 0.0) / 0.1) * cover * c;
        ink *= 1.0 - 0.12 * wet;
        let printed = select(col, vec3f(1.0), n == 0) * ink + 0.06 * wet * streak;
        col = mix(col, printed, cover);
        if (n == 0) { alpha = mix(fc.a, tc.a, cover); }

        if (t > 0.0 && t < 1.0) {
            let us = u + dir * SHADOW;
            shade *= 1.0 - 0.35 * smoothstep(-BEAD - SHADOW_SOFT, -BEAD + SHADOW_SOFT, us)
                * (1.0 - smoothstep(HOLDER - SHADOW_SOFT, HOLDER + SHADOW_SOFT, us));
            let bead = BEAD * (0.55 + 0.6 * sp_noise(vec2f(v * 7.0, i * 5.0)));
            let bx = clamp((u + 0.5 * bead) / (0.5 * bead), -1.0, 1.0);
            let bz = sqrt(1.0 - bx * bx);
            let bead_mask = smoothstep(-bead - AA, -bead + AA, u) * (1.0 - smoothstep(-AA, AA, u));
            var bc = ink_color(i) * (0.45 + 0.55 * bz) * (0.92 + 0.16 * sp_noise(vec2f(v * 30.0, u * 120.0)));
            bc += 0.35 * pow(smoothstep(0.75, 1.0, bz), 3.0) * (0.6 + 0.4 * sp_noise(vec2f(v * 40.0, i)));
            let rubber = smoothstep(-AA, AA, u) * (1.0 - smoothstep(RUBBER - AA, RUBBER + AA, u));
            let holder = smoothstep(RUBBER - AA, RUBBER + AA, u) * (1.0 - smoothstep(HOLDER - AA, HOLDER + AA, u));
            let hx = clamp((u - RUBBER) / (HOLDER - RUBBER) * 2.0 - 1.0, -1.0, 1.0);
            var metal = vec3f(0.62, 0.64, 0.67) * (0.55 + 0.45 * sqrt(1.0 - hx * hx));
            metal += 0.3 * (1.0 - smoothstep(0.0, 0.15, abs(hx + 0.35 * dir)));
            metal *= 1.0 - 0.5 * smoothstep(0.8, 1.0, abs(hx));
            let rc = vec3f(0.1, 0.11, 0.12) + 0.12 * (1.0 - smoothstep(0.0, 0.004, abs(u - 0.0025)));
            // The squeegee only tints the print: over a transparent clip, it adds no alpha.
            tool = vec4f(bead_mask * bc + rubber * rc + holder * metal, bead_mask + rubber + holder);
        }
    }
    col = col * shade * (1.0 - tool.a) + tool.rgb;
    return vec4f(col, alpha);
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
