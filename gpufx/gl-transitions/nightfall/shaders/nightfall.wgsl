// Port of Nightfall.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Nightfall.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TW: f32 = 0.16;

fn bent(q: vec2f, dir: vec2f) -> f32 {
    let y = dot(q, vec2f(-dir.y, dir.x));
    return dot(q, dir) - params.bow * y * y;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let a = vec2f(0.5 * ratio, 0.5);
    let b = vec2f(a.x, -a.y);
    let x = bent((uv - 0.5) * vec2f(ratio, 1.0), dir);
    let e = a.x * abs(dir.x) + a.y * abs(dir.y);
    let n = max(params.night, 0.05);
    // A bent line's extremes are at the corners or bounded by the straight one;
    // 0.09 covers the twilight rim, which reaches 0.08 ahead of the line.
    let lo = min(-e, min(min(bent(a, dir), bent(-a, dir)), min(bent(b, dir), bent(-b, dir)))) - 0.09;
    let hi = max(e, max(max(bent(a, dir), bent(-a, dir)), max(bent(b, dir), bent(-b, dir)))) + 0.09;
    let t = mix(progress, smoothstep(0.0, 1.0, progress), 0.25);
    let d = mix(lo, hi + n, t);
    let mid = d - 0.5 * n;
    let ahead = smoothstep(mid - 0.12 * n, mid + 0.12 * n, x);
    let c = mix(to_color(uv), from_color(uv), ahead);
    let l = dot(c.rgb, vec3f(0.299, 0.587, 0.114));
    // Bright parts keep the light a little longer at dusk and catch it earlier at dawn, like peaks.
    let into = min(d - x, x - d + n) - 0.06 * l;
    let dark = smoothstep(-0.25 * TW, TW, into) * mix(0.75, 1.0, smoothstep(0.0, 0.5 * n, into));
    let gi = (into - 0.1 * TW) / (0.6 * TW);
    let rim = max(1.0 - gi * gi, 0.0);
    // The low sun's light spreads far ahead of the line, so it fades in and out with the transition.
    let env = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    let wide = env * exp(-max(-into, 0.0) / 0.3) * (1.0 - dark);
    let sun = mix(params.dawn.rgb, params.dusk.rgb, ahead);
    let lit = mix(c.rgb, vec3f(l), 0.7) * params.moon.rgb * 1.2 * (0.12 + 0.6 * l * l);
    var col = mix(c.rgb, lit, dark * params.darkness);
    col = mix(col, col * sun * 1.25, clamp(0.6 * rim * rim + 0.35 * wide, 0.0, 1.0));
    return vec4f(col, c.a);
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
