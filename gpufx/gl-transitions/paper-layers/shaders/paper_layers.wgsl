// Port of PaperLayers.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaperLayers.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const MAX_LAYERS: f32 = 8.0;
// Part of the progress at which the last sheet lands, and longest slide of one sheet.
const STACKED: f32 = 0.74;
const SLIDE: f32 = 0.2;
// Height a sheet falls from, as the extra distance its shadow is cast at.
const LIFT: f32 = 3.0;
const SHADOW: vec2f = vec2f(0.012, -0.018);
// Softness of the cut edges and of the shadows' edges, in brightness.
const CUT: f32 = 0.012;
const SHADOW_CUT: f32 = 0.05;
// Radius over which the brightness is softened before it is cut, in frame heights.
const BLUR: f32 = 0.004;
const SHADOW_BLUR: f32 = 0.01;
const EDGE: f32 = 0.0015;

fn luma(c: vec4f) -> f32 { return dot(c.rgb, vec3f(0.299, 0.587, 0.114)); }

fn pl_hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn grain(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(pl_hash(i), pl_hash(i + vec2f(1.0, 0.0)), f.x), mix(pl_hash(i + vec2f(0.0, 1.0)), pl_hash(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// Brightness of the second clip at p (whose color is c), softened over a small disc.
fn soft_luma(p: vec2f, c: vec4f, radius: f32, aspect: vec2f) -> f32 {
    let r = radius / aspect;
    var l = luma(c);
    l += luma(to_color(mirror(p + r * vec2f(0.0, 1.0))));
    l += luma(to_color(mirror(p + r * vec2f(0.866, -0.5))));
    l += luma(to_color(mirror(p + r * vec2f(-0.866, -0.5))));
    return l / 4.0;
}

// Coverage of sheet k of n: the whole frame for the first one, else where l reaches its threshold.
fn cut(k: f32, n: f32, l: f32, soft: f32) -> f32 {
    if (k < 0.5) { return 1.0; }
    let thr = k / n;
    return smoothstep(thr - soft, thr + soft, l);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let paper = params.paper;
    let n = clamp(f32(params.layers), 2.0, MAX_LAYERS);
    let sh = clamp(params.shadow, 0.0, 1.0);
    let aspect = vec2f(ratio, 1.0);
    let shadow_offset = SHADOW / aspect;
    let to_photo = smoothstep(STACKED - 0.03, 1.0, progress);
    let rest = to_color(uv);
    var rest_luma = 0.0;
    var rest_shadow_color = vec4f(0.0);
    var rest_shadow = 0.0;
    let n1 = n - 1.0;
    // Short enough that at most two sheets slide at once.
    let slide = min(SLIDE, 2.0 * STACKED / (n1 + 2.0));
    let spacing = (STACKED - slide) / n1;
    if (progress >= slide) {
        rest_luma = soft_luma(uv, rest, BLUR, aspect);
        let ps = uv - shadow_offset;
        rest_shadow_color = to_color(mirror(ps));
        rest_shadow = soft_luma(ps, rest_shadow_color, SHADOW_BLUR, aspect);
    }
    var color = from_color(uv);
    for (var ki = 0; ki < 8; ki++) {
        let k = f32(ki);
        if (k >= n) { break; }
        let t = clamp((progress - k * spacing) / slide, 0.0, 1.0);
        if (t <= 0.0) { continue; }
        let e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
        let lift = 1.0 - smoothstep(0.5, 1.0, t);
        var q = (uv - 0.5) / (1.0 + 0.03 * lift) + 0.5;
        q.y -= (1.0 - e) * 1.15;
        let so = shadow_offset * (1.0 + LIFT * lift);
        var src = rest;
        var l = rest_luma;
        var ls = rest_shadow;
        var shadow_alpha = rest_shadow_color.a;
        if (t < 1.0) {
            src = to_color(mirror(q));
            l = soft_luma(q, src, BLUR, aspect);
            let cs = to_color(mirror(q - so));
            ls = soft_luma(q - so, cs, SHADOW_BLUR, aspect);
            shadow_alpha = cs.a;
        }
        let m = cut(k, n, l, CUT) * src.a * smoothstep(-EDGE, EDGE, q.y);
        let s = cut(k, n, ls, SHADOW_CUT) * shadow_alpha * smoothstep(-EDGE, EDGE, q.y - so.y);
        color = vec4f(color.rgb * (1.0 - sh * (1.0 - to_photo) * (0.7 - 0.35 * lift) * s * (1.0 - m)), color.a);
        // A shade of paper for the sheet's band of brightness, tinted by the photo.
        let level = 0.25 + 0.75 * k / n1;
        let plain = paper.rgb * level;
        let tinted = clamp(level + 1.25 * (src.rgb - luma(src)), vec3f(0.0), vec3f(1.0));
        var sheet = mix(plain, tinted, 0.9 * clamp(params.colorful, 0.0, 1.0));
        sheet *= 0.975 + 0.05 * grain(q * aspect * 160.0 + k * 37.0);
        color = mix(color, vec4f(sheet, paper.a), m);
    }
    return mix(color, rest, to_photo);
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
