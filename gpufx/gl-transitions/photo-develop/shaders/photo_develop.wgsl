// Port of PhotoDevelop.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PhotoDevelop.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn saturation(c: vec3f, s: f32) -> vec3f {
    let lum = dot(c, vec3f(0.2126, 0.7152, 0.0722));
    return mix(vec3f(lum), c, s);
}

fn transition(uv: vec2f, p: f32) -> vec4f {
    let a = from_color(uv);
    let b = to_color(uv);
    let card = params.card;
    // The card only shows where the clips are: it takes the first clip alpha, then the second.
    let split = mix(0.1, 0.7, clamp(params.wash, 0.0, 1.0));
    let card_alpha = card.a * mix(a.a, b.a, smoothstep(0.6 * split, split + 0.1, p));
    let card_color = card.rgb * card_alpha;
    let w = smoothstep(0.0, split, p);
    let from_lum = dot(a.rgb, vec3f(0.2126, 0.7152, 0.0722));
    let wl = clamp(w * (1.0 + 0.5 * from_lum), 0.0, 1.0);
    let washed = mix(a.rgb, mix(vec3f(from_lum), a.rgb, 0.4), w) * a.a;
    let outgoing = mix(washed, card_color, wl);
    let out_alpha = mix(a.a, card_alpha, wl);
    let x = clamp((p - split) / max(1.0 - split, 1e-3), 0.0, 1.0);
    let d = 1.0 - pow(1.0 - x, 1.5);
    let lum = dot(b.rgb, vec3f(0.2126, 0.7152, 0.0722));
    var dev = clamp((d - 0.45 * lum) / 0.55, 0.0, 1.0);
    dev = dev * dev * (3.0 - 2.0 * dev);
    let early = 1.0 - smoothstep(0.2, 0.95, d);
    var tinted = saturation(b.rgb, smoothstep(0.3, 1.0, d));
    tinted = mix(vec3f(0.6), tinted, mix(0.55, 1.0, d));
    let tone = mix(vec3f(-0.2, 0.06, 0.1), vec3f(0.12, -0.1, 0.06), smoothstep(0.15, 0.6, lum));
    tinted += tone * params.tint * early;
    let incoming = mix(card_color, clamp(tinted, vec3f(0.0), vec3f(1.0)) * b.a, dev);
    let in_alpha = mix(card_alpha, b.a, dev);
    let color = select(incoming, outgoing, p < split);
    let alpha = select(in_alpha, out_alpha, p < split);
    if (alpha <= 0.0) { return vec4f(0.0); }
    return vec4f(clamp(color / alpha, vec3f(0.0), vec3f(1.0)), alpha);
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
