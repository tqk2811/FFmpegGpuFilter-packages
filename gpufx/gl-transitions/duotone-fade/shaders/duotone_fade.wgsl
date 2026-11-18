// Port of DuotoneFade.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DuotoneFade.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn df_hash(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.xyx) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn df_luma(c: vec4f) -> f32 {
    return clamp(dot(c.rgb, vec3f(0.299, 0.587, 0.114)), 0.0, 1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let grain = params.grain;
    let a = from_color(uv);
    let b = to_color(uv);
    let la = df_luma(a);
    let lb = df_luma(b);
    // Fixed print grain, in cells of about 1/360 of the shorter side.
    let q = uv * 360.0 * vec2f(max(ratio, 1.0), max(1.0 / ratio, 1.0));
    let g = df_hash(floor(q)) - 0.5;
    let inks = smoothstep(0.0, 0.35, progress);
    let lift = smoothstep(0.65, 1.0, progress);
    var amount = min(clamp(inks * 1.35 - 0.35 * la, 0.0, 1.0), clamp((1.0 - lift) * 1.35 - 0.35 * lb, 0.0, 1.0));
    amount = amount * amount * (3.0 - 2.0 * amount);
    let x = smoothstep(0.25, 0.75, progress) * 1.6 - 0.3;
    let t = lb + 0.2 * grain * g;
    let s = smoothstep(t - 0.15, t + 0.15, x);
    let c = 0.4 * params.contrast;
    let tone = smoothstep(c + 0.03, 1.03 - c, mix(la, lb, s) + 0.08 * grain * g);
    let ink = mix(params.shadow_ink, params.highlight_ink, tone);
    // Premultiplied blend; where neither clip is drawn nothing is printed.
    let base = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), s);
    if (base.a <= 0.0) { return vec4f(0.0); }
    return vec4f(mix(base.rgb / base.a, ink.rgb, amount * ink.a), base.a);
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
