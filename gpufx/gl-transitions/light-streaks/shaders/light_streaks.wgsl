// Port of LightStreaks.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightStreaks.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const BLUR_TAPS: i32 = 6;
// Taps on each side of a streak, spaced further and further apart along its falloff.
const STREAK_TAPS: i32 = 11;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.xyx) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn frame(st: vec2f, m: f32) -> vec4f {
    if (m <= 0.0) { return from_color(st); }
    if (m >= 1.0) { return to_color(st); }
    return mix(from_color(st), to_color(st), m);
}

fn glow(c: vec4f, knee: f32) -> vec3f {
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    return c.rgb * c.a * smoothstep(knee, knee + 0.2, lum);
}

// One clip only, for the blur and streak taps: during the switch, every other tap reads each clip.
fn light(st: vec2f, m: f32, incoming: bool) -> vec4f {
    if (m <= 0.0) { return from_color(st); }
    if (m >= 1.0) { return to_color(st); }
    return select(from_color(st), to_color(st), incoming);
}

fn light_weight(m: f32, incoming: bool) -> f32 {
    if (m <= 0.0 || m >= 1.0) { return 1.0; }
    return select(2.0 * (1.0 - m), 2.0 * m, incoming);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    // Eased in on the first clip, and quickly out after the switch so the second lands sharp.
    let amount = select(pow(2.0 - 2.0 * p, 3.0), smoothstep(0.0, 0.5, p), p < 0.5);
    let peak = amount * amount * amount;
    let m = smoothstep(0.44, 0.56, p);
    let axis = select(vec2f(1.0, 0.0), vec2f(0.0, 1.0), params.vertical != 0u);
    // A small shift of the taps blends their copies into a smooth smear.
    let jitter = hash12(floor(uv * vec2f(ratio, 1.0) * 997.0)) - 0.5;
    let smear = params.blur * amount;
    var base = vec3f(0.0);
    var alpha = 0.0;
    var total = 0.0;
    for (var i = 0; i < BLUR_TAPS; i++) {
        let t = (f32(i) + 0.5 + jitter) / f32(BLUR_TAPS) - 0.5;
        var w = 1.0 - abs(t);
        total += w;
        let incoming = i % 2 == 1;
        w *= light_weight(m, incoming);
        let c = light(mirror(uv + axis * t * smear), m, incoming);
        base += w * c.rgb * c.a;
        alpha += w * c.a;
    }
    base /= total;
    alpha /= total;
    let falloff = 0.25 * params.reach * amount;
    let knee = mix(params.threshold, 0.8 * params.threshold, peak);
    var streak = glow(frame(uv, m), knee);
    var weights = 1.0;
    for (var k = 1; k <= STREAK_TAPS; k++) {
        let d = exp(0.14 * (f32(k) + 0.8 * jitter)) - 1.0;
        let span = 0.14 * (d + 1.0);
        var hue = mix(vec3f(1.0), params.tint.rgb, smoothstep(0.0, 0.8, d));
        hue *= exp(-d * vec3f(0.6, 0.2, -0.15));
        let w = exp(-d) * span * 4.0;
        let incoming = k % 2 == 1;
        let ahead = light(mirror(uv + axis * d * falloff), m, incoming);
        let behind = light(mirror(uv - axis * d * falloff), m, !incoming);
        streak += w * hue * (glow(ahead, knee) * light_weight(m, incoming) + glow(behind, knee) * light_weight(m, !incoming));
        weights += 2.0 * w;
    }
    streak *= params.intensity * amount * (0.6 + 2.4 * peak) * 2.0 / weights;
    // Compressed, so bright skies never flatten into white.
    streak = 0.85 * (1.0 - exp(-streak));
    base = min(base * (1.0 + 0.2 * peak), vec3f(alpha));
    let color = base + streak - base * streak;
    let a = alpha + max(streak.r, max(streak.g, streak.b)) * (1.0 - alpha);
    return vec4f(clamp(color / max(a, 1e-5), vec3f(0.0), vec3f(1.0)), a);
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
