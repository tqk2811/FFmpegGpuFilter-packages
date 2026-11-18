// Port of SketchDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SketchDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn sd_hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn sd_noise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(sd_hash(i), sd_hash(i + vec2f(1.0, 0.0)), f.x),
        mix(sd_hash(i + vec2f(0.0, 1.0)), sd_hash(i + vec2f(1.0, 1.0)), f.x),
        f.y);
}

// Luma and alpha of the second clip: outlines follow both.
fn sd_tone(uv: vec2f) -> vec2f {
    let c = to_color(uv);
    return vec2f(dot(c.rgb, vec3f(0.299, 0.587, 0.114)), c.a);
}

// One family of hatching strokes along direction d, as thick as the shadow is dark.
fn sd_hatch(q: vec2f, d: vec2f, dark: f32) -> f32 {
    let s = dot(q, d) * 60.0 + 0.5 * sd_noise(q * 9.0 + d * 13.0);
    let row = floor(s);
    let along = dot(q, vec2f(-d.y, d.x)) * 8.0 + sd_hash(vec2f(row, d.y * 7.0)) * 5.0;
    let cell = floor(along);
    let k = sd_hash(vec2f(row, cell) + d * 31.0);
    let gap = smoothstep(0.0, 0.12, fract(along)) * (1.0 - smoothstep(0.75 - 0.2 * k, 1.0, fract(along)));
    let w = 0.5 * clamp(dark, 0.0, 1.0) * (0.7 + 0.3 * k);
    return (1.0 - smoothstep(w - 0.24, w, abs(fract(s) - 0.5))) * gap * (0.6 + 0.4 * k);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let q = vec2f(uv.x * ratio, uv.y);
    let wob = (vec2f(sd_noise(q * 6.0), sd_noise(q * 6.0 + 17.0)) - 0.5) * 0.004;
    let su = uv + wob * (1.0 - progress);
    let dx = vec2f(0.001 * params.line_width / ratio, 0.0);
    let dy = vec2f(0.0, 0.001 * params.line_width);
    let tl = sd_tone(su - dx + dy);
    let tm = sd_tone(su + dy);
    let tr = sd_tone(su + dx + dy);
    let ml = sd_tone(su - dx);
    let mr = sd_tone(su + dx);
    let bl = sd_tone(su - dx - dy);
    let bm = sd_tone(su - dy);
    let br = sd_tone(su + dx - dy);
    let gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    let gy = (tl + 2.0 * tm + tr) - (bl + 2.0 * bm + br);
    let g = max(length(vec2f(gx.x, gy.x)), length(vec2f(gx.y, gy.y))) * max(params.edges, 0.0);
    let outline = smoothstep(0.12, 0.5, g);
    let to_c = to_color(uv);
    let l = clamp((tm.x + bm.x + ml.x + mr.x) * 0.25, 0.0, 1.0);

    let grain = 0.65 + 0.35 * sd_noise(q * vec2f(180.0, 60.0));
    let order = sd_noise(q * 3.0 + 4.0);
    let fine = sd_noise(q * 24.0);
    let draw_outline = smoothstep(0.0, 0.1, progress - (0.22 * order + 0.05 * fine));
    let draw_hatch = smoothstep(0.0, 0.12, progress - (0.2 + 0.2 * order + 0.05 * fine));

    let fill = smoothstep(0.0, 0.22, progress - (0.4 + 0.25 * l + 0.1 * order));

    let dark = 1.0 - l;
    let h1 = sd_hatch(q, vec2f(0.7071, 0.7071), smoothstep(0.35, 0.9, dark));
    let h2 = sd_hatch(q, vec2f(0.7071, -0.7071), smoothstep(0.65, 1.0, dark));
    var hatch = params.hatching * 0.8 * max(h1, 0.8 * h2) * to_c.a;

    hatch *= draw_hatch * (1.0 - 0.6 * fill);
    var pencil = max(outline * draw_outline, hatch) * grain;
    pencil *= 1.0 - smoothstep(0.7, 1.0, progress);

    let paper = params.paper;
    var base = mix(from_color(uv), paper, smoothstep(0.02, 0.38, progress));
    let sat = smoothstep(0.55, 1.0, progress);
    let tone = vec4f(paper.rgb * mix(0.3, 1.0, l), paper.a * to_c.a);
    let col = mix(tone, to_c, sat);
    base = mix(base, col, fill);
    return mix(base, params.ink, pencil);
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
