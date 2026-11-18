// Port of GlintDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlintDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const REACH: f32 = 6.0;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.xyx) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

// One thin ray along x, from the glint center to its tip at x = len (in cells).
fn ray(d: vec2f, len: f32, width: f32) -> f32 {
    let a = abs(d.x) / len;
    if (a >= 1.0) { return 0.0; }
    let fall = (1.0 - a) * (1.0 - a);
    let w = width * (1.0 - 0.7 * a);
    return fall * exp(-d.y * d.y / (w * w));
}

fn spectrum(a: f32) -> vec3f {
    return 0.5 + 0.5 * cos(6.2831853 * (a + vec3f(0.0, 0.33, 0.67)));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let t = 1.0 - abs(2.0 * p - 1.0);
    let amount = t * (2.0 - t);
    let m = smoothstep(0.42, 0.58, p);
    let from_c = from_color(uv);
    let to_c = to_color(uv);
    let c = mix(vec4f(from_c.rgb * from_c.a, from_c.a), vec4f(to_c.rgb * to_c.a, to_c.a), m);
    if (c.a <= 0.0) { return vec4f(0.0); }
    let base = c.rgb / c.a;
    // A grid of glint cells, turned with the cross so its long rays run along rows and columns.
    let cell = params.size / REACH;
    let ang = radians(params.rotation);
    let cs = vec2f(cos(ang), sin(ang));
    let aspect = vec2f(ratio, 1.0);
    let o = (uv - 0.5) * aspect;
    let q = vec2f(o.x * cs.x + o.y * cs.y, o.y * cs.x - o.x * cs.y) / cell;
    let home = floor(q);
    // Thin rays, in cells, thin enough to vanish before the next row of cells.
    let width = min(0.0022 / cell, 0.07);
    let threshold = params.threshold;
    var light = vec3f(0.0);
    // The own cell, the cells along its row and column, and its four diagonal neighbours.
    for (var k = 0; k < 29; k++) {
        let fk = f32(k);
        var off = vec2f(0.0);
        if (k >= 1 && k <= 12) {
            off = vec2f(select(fk - 6.0, fk - 7.0, fk < 7.0), 0.0);
        } else if (k >= 13 && k <= 24) {
            off = vec2f(0.0, select(fk - 18.0, fk - 19.0, fk < 19.0));
        } else if (k >= 25) {
            off = vec2f(f32(k % 2) * 2.0 - 1.0, select(1.0, -1.0, fk < 27.0));
        }
        // The rays are never longer than this, so farther glints cannot reach the pixel.
        if (max(abs(off.x), abs(off.y)) > REACH * amount + 1.0) { continue; }
        let id = home + off;
        if (hash12(id + 89.5) > 0.55) { continue; }
        let h0 = hash12(id + 0.5);
        let h1 = hash12(id + 19.5);
        let h2 = hash12(id + 41.5);
        let h3 = hash12(id + 67.5);
        // The glint sits somewhere in its cell, so the grid never shows.
        let center = id + 0.5 + 0.6 * (vec2f(h0, h1) - 0.5);
        let cw = center * cell;
        let st = vec2f(cw.x * cs.x - cw.y * cs.y, cw.x * cs.y + cw.y * cs.x) / aspect + 0.5;
        if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) { continue; }
        let turn = 0.15 + 0.7 * h3;
        let src = select(to_color(st), from_color(st), m < turn);
        let lum = dot(src.rgb, vec3f(0.2126, 0.7152, 0.0722)) * src.a;
        let knee = threshold + 0.8 * (1.0 - threshold) * h2;
        let b = smoothstep(knee, knee + 0.2 * (1.0 - threshold) + 1e-3, lum);
        if (b <= 0.0) { continue; }
        let twinkle = (0.6 + 0.4 * sin(6.2831853 * (h2 + (1.5 + h0) * p))) * smoothstep(0.0, 0.12, abs(m - turn));
        let len = REACH * amount * (0.45 + 0.55 * b) * (0.3 + 0.7 * h1 * h1) * (0.85 + 0.15 * twinkle);
        let d = q - center;
        let r = length(d);
        var star = ray(d, len, width) + ray(d.yx, len, width);
        if (params.diagonals != 0u) {
            let e = vec2f(d.x + d.y, d.x - d.y) * 0.70710678;
            star += 0.5 * (ray(e, 0.25 * len, width) + ray(e.yx, 0.25 * len, width));
        }
        let cr = r / (0.08 * len);
        star += exp(-cr * cr) + 0.3 * exp(-r / 0.2);
        let along = r / len;
        let hue = mix(vec3f(1.0), spectrum(1.3 * along + h0), params.rainbow * smoothstep(0.05, 0.4, along));
        let col = mix(src.rgb / max(max(src.r, max(src.g, src.b)), 1e-3), vec3f(1.0), 0.6);
        light += b * twinkle * star * hue * col;
    }
    light *= params.tint.rgb * params.intensity * amount * amount;
    // Compressed, so crossing rays never flatten into white.
    light = 1.0 - exp(-light);
    return vec4f(clamp(base + light - base * light, vec3f(0.0), vec3f(1.0)), c.a);
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
