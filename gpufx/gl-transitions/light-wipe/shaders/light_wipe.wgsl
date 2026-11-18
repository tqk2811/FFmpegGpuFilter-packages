// Port of LightWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAPS: i32 = 12;

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

// A gentle ease in and out, which does not linger at the ends.
fn ease(t: f32) -> f32 {
    return 0.5 * (t + t * t * (3.0 - 2.0 * t));
}

// Both clips are always sampled, so that no texture read sits in a divergent branch.
fn frame(st: vec2f, m: f32) -> vec4f {
    return mix(from_color(st), to_color(st), m);
}

fn highlight(c: vec4f) -> vec3f {
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    return c.rgb * c.a * smoothstep(0.45, 1.0, lum);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let intensity = params.intensity;
    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let w = max(params.width, 0.001);
    let s = 0.35 * w;
    // The band starts and ends outside of the frame, with the switch out of sight.
    let margin = s + 2.0 * w;
    let pos = -e - margin + 2.0 * (e + margin) * ease(progress);
    // Signed distance to the middle of the band: < 0 has been swept.
    let d = dot(p, dir) - pos;
    let m = 1.0 - smoothstep(-s, s, d);

    let env = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    let core = exp(-d * d / (w * w));
    let g = (d + 2.2 * w) / (0.3 * w);
    let glint = 0.45 * exp(-g * g);
    let halo = 0.35 * exp(-abs(d) / (5.0 * w));
    let band = (core + glint + halo) * env * intensity;
    let glow = (core + glint) * env * intensity;

    let c = frame(uv, m);

    var bloom = vec3f(0.0);
    let spread = min(3.0 * w, 0.12);
    for (var i = 0; i < TAPS; i++) {
        let t = (f32(i) + 0.5) / f32(TAPS) * 2.0 - 1.0;
        let st = mirror((p + dir * (t * spread)) / vec2f(ratio, 1.0) + 0.5);
        let dq = dot((st - 0.5) * vec2f(ratio, 1.0), dir) - pos;
        bloom += (1.0 - abs(t)) * highlight(frame(st, 1.0 - smoothstep(-s, s, dq)));
    }
    bloom /= 0.5 * f32(TAPS);

    let hue = mix(params.color.rgb, vec3f(1.0), core * core);
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    // The light lifts the picture, the bright parts more: exposure that rolls off softly to white.
    let light = hue * band * (0.3 + 0.9 * lum) + hue * bloom * glow * 4.0 + hue * core * env * intensity * 1.6;
    let rgb = 1.0 - (1.0 - c.rgb) * exp(-light);
    // Light adds to the picture, not to its alpha.
    return vec4f(rgb, c.a);
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
