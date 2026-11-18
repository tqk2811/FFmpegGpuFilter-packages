// Port of Ascii.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Ascii.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Width of a character cell, in cell heights.
const ASPECT: f32 = 0.6;
const STROKE: f32 = 0.05;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn segment(q: vec2f, a: vec2f, b: vec2f) -> f32 {
    let pa = q - a;
    let ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Distance to the strokes of the character of density g, 0 (" ") to 9 ("@"), q in cell heights from its center.
fn glyph(g: f32, q: vec2f) -> f32 {
    if (g < 0.5) { return 1.0; } // " "
    if (g < 1.5) { return length(q - vec2f(0.0, -0.27)) - 0.035; } // "."
    if (g < 2.5) { return min(length(q - vec2f(0.0, -0.25)), length(q - vec2f(0.0, 0.1))) - 0.035; } // ":"
    if (g < 3.5) { return segment(q, vec2f(-0.17, 0.0), vec2f(0.17, 0.0)) - STROKE; } // "-"
    if (g < 4.5) { // "="
        return min(segment(q, vec2f(-0.18, 0.1), vec2f(0.18, 0.1)), segment(q, vec2f(-0.18, -0.1), vec2f(0.18, -0.1))) - STROKE;
    }
    if (g < 5.5) { // "+"
        return min(segment(q, vec2f(-0.19, 0.0), vec2f(0.19, 0.0)), segment(q, vec2f(0.0, -0.19), vec2f(0.0, 0.19))) - STROKE;
    }
    if (g < 6.5) { // "*"
        var d = segment(q, vec2f(0.0, -0.2), vec2f(0.0, 0.2));
        d = min(d, segment(q, vec2f(-0.18, -0.11), vec2f(0.18, 0.11)));
        d = min(d, segment(q, vec2f(-0.18, 0.11), vec2f(0.18, -0.11)));
        return d - STROKE;
    }
    if (g < 7.5) { // "#"
        var d = min(segment(q, vec2f(-0.06, -0.3), vec2f(-0.1, 0.3)), segment(q, vec2f(0.12, -0.3), vec2f(0.08, 0.3)));
        d = min(d, min(segment(q, vec2f(-0.24, 0.11), vec2f(0.24, 0.11)), segment(q, vec2f(-0.24, -0.11), vec2f(0.24, -0.11))));
        return d - STROKE;
    }
    if (g < 8.5) { // "%"
        var d = segment(q, vec2f(-0.2, -0.3), vec2f(0.2, 0.3));
        d = min(d, abs(length(q - vec2f(-0.13, 0.19)) - 0.08));
        d = min(d, abs(length(q - vec2f(0.13, -0.19)) - 0.08));
        return d - STROKE;
    }
    // "@": a ring around a small "a".
    var d = abs(length(q) - 0.25);
    d = min(d, abs(length(q - vec2f(-0.02, 0.0)) - 0.1));
    d = min(d, segment(q, vec2f(0.08, 0.1), vec2f(0.08, -0.12)));
    return d - 0.8 * STROKE;
}

fn density(c: vec4f) -> f32 {
    return floor(pow(clamp(dot(c.rgb, vec3f(0.299, 0.587, 0.114)) * c.a, 0.0, 1.0), 0.75) * 9.99);
}

fn cell_color(center: vec2f, dims: vec2f, incoming: bool, ratio: f32) -> vec4f {
    var c = vec4f(0.0);
    for (var i = 0; i < 4; i++) {
        let fi = f32(i);
        let o = (vec2f(fi - 2.0 * floor(fi / 2.0), floor(fi / 2.0)) - 0.5) * 0.5 * dims;
        let st = clamp((center + o) / vec2f(ratio, 1.0) + 0.5, vec2f(0.0), vec2f(1.0));
        if (incoming) { c += to_color(st); } else { c += from_color(st); }
    }
    return c * 0.25;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let h = params.cell_size;
    let colored = params.colored != 0u;
    let ink = params.ink;
    let background = params.background;
    let fp = (uv - 0.5) * vec2f(ratio, 1.0);
    let dims = vec2f(ASPECT * h, h);
    let cell = floor(fp / dims);
    let center = (cell + 0.5) * dims;
    let q = (fp - center) / h;

    let r = hash12(cell + 100.0);
    let at = 0.4 + 0.2 * r;
    let incoming = p > at;
    let c = cell_color(center, dims, incoming, ratio);
    var g = density(c);
    let scramble = 1.0 - smoothstep(0.02, 0.045, abs(p - at));
    if (hash12(cell + floor(p * 40.0) * vec2f(17.0, 31.0)) < scramble) {
        g = 1.0 + floor(9.0 * hash12(cell * 1.7 + floor(p * 40.0) * vec2f(5.0, 11.0)));
    }

    let cover = 1.0 - smoothstep(-0.02, 0.02, glyph(g, q));
    var tint = ink.rgb;
    var alpha = ink.a * c.a;
    var behind = background.rgb;
    if (colored) {
        tint = mix(c.rgb, c.rgb / max(max(c.r, max(c.g, c.b)), 0.05), 0.7);
        alpha = c.a;
        behind = mix(background.rgb, c.rgb, 0.3);
    }
    let back = vec4f(behind, background.a * c.a);
    let text = mix(back, vec4f(clamp(tint, vec3f(0.0), vec3f(1.0)), alpha), cover);

    let into = 0.05 + 0.22 * hash12(cell + 200.0);
    let outof = 0.95 - 0.22 * hash12(cell + 300.0);
    let show = smoothstep(into, into + 0.08, p) * (1.0 - smoothstep(outof - 0.08, outof, p));
    var image = to_color(uv);
    if (p < 0.5) { image = from_color(uv); }
    return mix(image, text, show);
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
