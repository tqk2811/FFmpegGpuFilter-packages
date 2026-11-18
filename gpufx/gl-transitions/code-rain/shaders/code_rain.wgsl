// Port of CodeRain.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CodeRain.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn hash42(p: vec2f) -> vec4f {
    var p4 = fract(p.xyxy * vec4f(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

fn band(d: vec4f) -> vec4f {
    return 1.0 - smoothstep(vec4f(0.3), vec4f(0.6), d);
}

// Coverage of the character of this cell at this time, drawn on a 5x7 dot grid in a 6x8 cell
// (local: 0..1 in the cell, from its top left), made of strokes picked by hashes.
fn glyph(cell: vec2f, t: f32, local: vec2f) -> f32 {
    let b = local * vec2f(6.0, 8.0) - 0.5;
    let x = b.x;
    let y = b.y;
    let d = 0.667 * y;
    // How far outside the spans 0..4, 0..6, 0..3 and 3..6, in dots.
    let x04 = abs(x - 2.0) - 2.0;
    let y06 = abs(y - 3.0) - 3.0;
    let y03 = abs(y - 1.5) - 1.5;
    let y36 = abs(y - 4.5) - 1.5;
    let seed = cell + t * vec2f(37.0, 61.0);
    // Strokes: three bars and a diagonal, the halves of the side verticals,
    // the halves of the middle vertical, the other diagonal and a short bar.
    let sa = band(abs(vec4f(y, y - 3.0, y - 6.0, x - d))) * band(vec4f(x04, x04, x04, y06));
    let sb = band(abs(vec4f(x, x, x - 4.0, x - 4.0))) * band(vec4f(y03, y36, y03, y36));
    let sc = band(abs(vec4f(x - 2.0, x - 2.0, x + d - 4.0, y - 1.0))) * band(vec4f(y03, y36, y06, abs(x - 2.0) - 1.0));
    var on = dot(step(vec4f(0.68), hash42(seed)), sa);
    on += dot(step(vec4f(0.68), hash42(seed + 41.0)), sb);
    on += dot(step(vec4f(0.68), hash42(seed + 83.0)), sc);
    return min(on, 1.0);
}

fn modf_(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let h = max(params.cell_size, 0.005);
    let dims = vec2f(0.75 * h, h);
    let fp = vec2f(uv.x * ratio, 1.0 - uv.y);
    // Shifted by odd fractions of a cell, so pixel centers do not fall on its lines at usual sizes.
    let grid = fp / dims + vec2f(0.389, 0.278);
    let cell = floor(grid);
    let local = grid - cell;
    let rc = hash12(cell + vec2f(97.0, 131.0));
    let glow = params.glow;

    let r1 = hash12(vec2f(cell.x, 11.0));
    let r2 = hash12(vec2f(cell.x, 23.0));
    let r3 = hash12(vec2f(cell.x, 37.0));
    let big_t = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
    let len = max(params.trail, 0.01) * (0.5 + r3);
    let u = clamp((big_t - 0.03 - 0.5 * r1) / (0.3 + 0.12 * r2), 0.0, 1.0);
    let head = mix(-0.2, 1.0 + h + len, u * (0.7 + 0.3 * u));
    let dy = head - (cell.y - 0.278) * h;

    let a = from_color(uv);
    let b = to_color(uv);

    let cuv = clamp(vec2f((cell.x + 0.111) * dims.x / ratio, 1.0 - (cell.y + 0.222) * h), vec2f(0.0), vec2f(1.0));
    let ca = from_color(cuv);
    let lum = dot(ca.rgb, vec3f(0.299, 0.587, 0.114));
    let hue = ca.rgb / max(max(ca.r, max(ca.g, ca.b)), 0.05);
    let ink = mix(glow.rgb * glow.a, hue, params.tint) * (0.1 + 0.6 * lum);
    let near = smoothstep(-0.15, 0.0, dy);
    let dim = max(smoothstep(0.0, 0.3, big_t), near);
    let g = max(smoothstep(0.0, 0.2, big_t - 0.12 * rc), near);
    let passed = step(0.0, dy);
    let slow = modf_(floor(big_t * 12.0 + rc * 7.0), 32.0);
    let fast = 32.0 + modf_(floor(big_t * 40.0 + rc * 13.0), 32.0);
    let chr = glyph(cell, mix(slow, fast, passed), local);
    let code = a.rgb * (1.0 - 0.8 * dim) + ink * chr * g;

    let fade = clamp(1.0 - dy / len, 0.0, 1.0);
    let shade = 1.0 - smoothstep(0.3 * len, len, dy);
    let hot = 1.0 - smoothstep(h, 3.0 * h, dy);
    let col = mix(glow.rgb * 1.2, vec3f(1.0), 0.8 * hot) * glow.a;
    let stream = b.rgb * (1.0 - 0.8 * shade) + col * chr * (fade * (2.0 - fade) + hot * fade);

    let yy = (head - fp.y) / (1.5 * h);
    let halo = 1.6 * u * (1.0 - u) * exp(-yy * yy) * (1.0 - smoothstep(0.25, 0.5, abs(local.x - 0.5)));
    let rgb = mix(code, stream, passed) + glow.rgb * glow.a * halo;
    return vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), mix(a.a, mix(b.a, a.a, shade), passed));
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
