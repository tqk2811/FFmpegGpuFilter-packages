// Port of ReededGlass.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ReededGlass.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.002;
// Width of the pane's shadow, in frame heights.
const SHADOW: f32 = 0.03;

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

fn behind(x: f32, y: f32, cut: f32, soft: f32) -> vec4f {
    let p = mirror(vec2f(x, y));
    return mix(to_color(p), from_color(p), smoothstep(cut - soft, cut + soft, x));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shine = params.shine;
    let strength = params.strength;
    let pw = clamp(params.pane_width, 0.05, 1.0);
    let t = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.6);
    // The pane starts and ends far enough off frame that its shadow is off frame too.
    let margin = SHADOW / ratio + 0.005;
    let left = mix(-pw - margin, 1.0 + margin, t);
    let right = left + pw;
    let cut = left + 0.5 * pw;
    let x = uv.x;
    let rw = pw / max(floor(pw * params.ribs + 0.5), 1.0);
    let r = (x - left) / rw;
    let u = 2.0 * fract(r) - 1.0;
    // Strength 0 leaves the picture as is; from about 0.25 each rib flips the slice behind it.
    let bend = rw * strength * (0.5 * u + 1.6 * u * sqrt(1.0 - 0.6 * u * u));
    let soft = 0.5 * rw;
    let disp = 0.05 * strength;
    let g = behind(x - bend, uv.y, cut, soft);
    var c = vec4f(
        behind(x - bend * (1.0 + disp), uv.y, cut, soft).r,
        g.g,
        behind(x - bend * (1.0 - disp), uv.y, cut, soft).b,
        g.a);
    let seam = smoothstep(0.82, 1.0, abs(u));
    let hl = (u + 0.45) / 0.16;
    let rim = 1.0 - smoothstep(0.0, 0.006, min(x - left, right - x) * ratio);
    var lit = c.rgb * (1.0 - shine * (0.08 * u + 0.45 * seam + 0.4 * rim));
    lit += shine * (0.22 * exp(-hl * hl) + 0.05) * c.a;
    c = vec4f(mix(lit, vec3f(0.93, 0.96, 0.97) * c.a, 0.05 * shine), c.a);
    let inside = smoothstep(left - AA, left + AA, x) * (1.0 - smoothstep(right - AA, right + AA, x));
    var clear = select(from_color(uv), to_color(uv), x < cut);
    let shadow = 0.2 * shine * smoothstep(right - AA, right + AA, x) * (1.0 - smoothstep(0.0, SHADOW, (x - right) * ratio));
    clear = vec4f(clear.rgb * (1.0 - shadow), clear.a);
    return mix(clear, c, inside);
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
