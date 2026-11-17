// Port of Hologram.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Hologram.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;
const STEPS: f32 = 32.0;

fn hash(p_in: vec2f) -> f32 {
    var p = fract(p_in * vec2f(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

fn luma(c: vec3f) -> f32 { return dot(c, vec3f(0.299, 0.587, 0.114)); }

fn premultiplied(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn source(uv: vec2f, m: f32) -> vec4f {
    return select(from_color(uv), to_color(uv), m > 0.5);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = progress;
    let jitter = params.jitter;
    let flicker = params.flicker;
    let h = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.7, 1.0, p));
    let b = smoothstep(0.0, 1.0, 1.0 - abs(p - 0.5) / 0.22);
    let f = floor(p * STEPS);
    let band = floor(uv.y * 36.0);
    let jump = step(1.0 - (0.2 + 0.6 * b) * h, hash(vec2f(band, f)));
    var offset = (hash(vec2f(band, f + 0.37)) - 0.5) * 2.0 * jitter * jump * (0.3 + 0.7 * b);
    offset += sin(uv.y * 23.0 + f * 1.7) * 0.0015 * h;
    let q = uv + vec2f(offset, 0.0);
    let m = step(hash(vec2f(floor(uv.y * 24.0), 7.0)), (p - 0.35) / 0.3);
    // The luma of the picture in the tint, with colored fringes weighted by their texels' alpha.
    let c = source(clamp(q, vec2f(0.0), vec2f(1.0)), m);
    let dx = vec2f(0.003 + 0.01 * b, 0.0);
    let l = luma(c.rgb);
    let cr = source(clamp(q + dx, vec2f(0.0), vec2f(1.0)), m);
    let cb = source(clamp(q - dx, vec2f(0.0), vec2f(1.0)), m);
    let lr = luma(cr.rgb) * cr.a;
    let lb = luma(cb.rgb) * cb.a;
    let g = smoothstep(vec3f(0.05), vec3f(0.9), vec3f(lr, l, lb));
    var holo = params.tint.rgb * (0.06 + 1.25 * g) + 0.45 * g * g * g;
    let roll = fract(uv.y + 2.0 * p);
    holo += params.tint.rgb * 0.35 * smoothstep(0.85, 1.0, roll) * (1.0 - smoothstep(0.98, 1.0, roll));
    holo = clamp(holo, vec3f(0.0), vec3f(1.0));
    let inside = step(0.0, q.x) * step(q.x, 1.0);
    let lines = 0.5 + 0.5 * sin((uv.y * params.scanlines - p * 6.0) * 2.0 * PI);
    var vis = mix(1.0, 0.15 + 0.85 * lines, h);
    vis *= 1.0 - flicker * (0.25 + 0.75 * b) * hash(vec2f(f, 3.1)) * h;
    let gap = step(hash(vec2f(floor(uv.y * 90.0), f + 0.71)), flicker * 0.45 * b);
    vis *= 1.0 - gap;
    let layer = vec4f(holo, c.a * vis * inside);
    let plain = premultiplied(source(uv, m));
    let back = premultiplied(vec4f(params.background.rgb, params.background.a * max(plain.a, layer.a)));
    let holo_color = premultiplied(layer) + back * (1.0 - layer.a);
    let o = mix(plain, holo_color, h);
    if (o.a > 0.0) { return vec4f(o.rgb / o.a, o.a); }
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
