// Port of LensFlare.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LensFlare.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const BLOOM_TAPS: i32 = 12;
const GHOSTS: i32 = 6;

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

fn premultiplied(c: vec4f) -> vec4f {
    return vec4f(c.rgb * c.a, c.a);
}

fn frame(st: vec2f, m: f32) -> vec4f {
    if (m <= 0.0) { return premultiplied(from_color(st)); }
    if (m >= 1.0) { return premultiplied(to_color(st)); }
    return mix(premultiplied(from_color(st)), premultiplied(to_color(st)), m);
}

fn highlight(c: vec4f) -> vec3f {
    let lum = dot(c.rgb, vec3f(0.2126, 0.7152, 0.0722));
    return c.rgb * smoothstep(0.55, 0.95, lum);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let intensity = params.intensity;
    let p = progress;

    let env = 4.0 * p * (1.0 - p);
    let peak = pow(env, 24.0);
    let aspect = vec2f(ratio, 1.0);
    let q = (uv - 0.5) * aspect;
    let r = radians(params.angle);
    let dir = vec2f(cos(r), -sin(r));
    let normal = vec2f(-dir.y, dir.x);
    let t = p - 0.5;
    let travel = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + 0.3;
    let along = travel * (2.0 * t) * (0.55 + 1.8 * t * t);
    let src = dir * along + normal * params.height;

    let d = q - src;
    let dist = length(d);
    let k = intensity * env;

    // The cut, under the glare: the second clip spreads out from the light in a soft circle,
    // slower as the flare gets dimmer so that it still reads as intended.
    let cut = mix(0.2, 0.06, clamp(intensity, 0.0, 1.0));
    let s = clamp((p - 0.5 + cut) / (2.0 * cut), 0.0, 1.0);
    let soft = 0.3;
    let reach = 0.5 * length(aspect) + length(src) + soft;
    let front = s * (reach + soft);
    let m = smoothstep(front, front - soft, dist);
    let base = frame(uv, m);

    let ax = abs(d.x);
    let ay = abs(d.y);
    let thin = exp(-ay * 140.0) * exp(-ax * 0.7);
    let wide = exp(-ay * 30.0) * exp(-ax * 1.6);
    let tint = params.color.rgb;
    let streak = (thin * mix(vec3f(1.0), tint, smoothstep(0.0, 0.3, ax)) + 0.5 * wide * tint) * 3.0;

    let core = vec3f(1.0, 0.97, 0.92) * exp(-dist * dist * 600.0) * 3.0 + mix(vec3f(1.0), tint, 0.5) * exp(-dist * 7.0) * 0.6;

    var ghosts = vec3f(0.0);
    for (var i = 0; i < GHOSTS; i++) {
        let fi = f32(i);
        let f = -0.45 + 0.42 * fi + 0.08 * sin(fi * 2.3);
        let g = -src * f;
        let size = 0.025 + 0.06 * fract(fi * 0.618 + 0.2);
        let gd = length(q - g) / size;
        let disc = smoothstep(1.0, 0.8, gd) * (0.35 + 0.65 * smoothstep(0.4, 0.95, gd));
        var hue = mix(tint, vec3f(1.0, 0.65, 0.35), fract(fi * 0.53));
        hue = mix(hue, vec3f(0.5, 1.0, 0.6), step(4.5, fi) * 0.6);
        ghosts += disc * hue * 0.45;
    }

    var bloom = vec3f(0.0);
    if (peak > 1e-3) {
        let radius = 0.06 * env;
        for (var i = 0; i < BLOOM_TAPS; i++) {
            let fi = f32(i);
            let a = fi * 2.39996;
            let rr = radius * sqrt((fi + 0.5) / f32(BLOOM_TAPS));
            let o = vec2f(cos(a), sin(a)) * rr / aspect;
            bloom += highlight(frame(mirror(uv + o), m));
        }
        bloom /= f32(BLOOM_TAPS);
    }

    // At the peak, the glare: a wide halo around the light and a light veil over the frame, to hide the cut.
    let glare = mix(vec3f(1.0), tint, 0.5) * peak * (0.45 + 2.2 * exp(-dist * 3.0));

    var light = k * (streak + core + ghosts) + intensity * (bloom * 2.5 * peak + glare);
    light = 1.0 - exp(-light);

    // Screened over the picture; the flare only shows on the picture, so transparency is kept.
    let c = base.rgb + light * base.a - base.rgb * light;
    if (base.a <= 0.0) { return vec4f(0.0); }
    return vec4f(clamp(c / base.a, vec3f(0.0), vec3f(1.0)), base.a);
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
