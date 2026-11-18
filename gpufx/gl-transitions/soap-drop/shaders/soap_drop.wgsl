// Port of SoapDrop.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SoapDrop.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAU: f32 = 6.2831853;
const AA: f32 = 0.002;
const LIGHT: vec3f = vec3f(-0.45, 0.55, 0.7);
const LIGHT_XY: vec2f = vec2f(-0.633, 0.774);
const HALFWAY: vec3f = vec3f(-0.244, 0.299, 0.923);

fn sd_hash(p0: f32) -> f32 {
    var p = fract(p0 * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

fn modf_(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

// Periodic with period n so the angle wrap leaves no seam.
fn sd_noise(x: f32, n: f32) -> f32 {
    let i = floor(x);
    var f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(sd_hash(modf_(i, n)), sd_hash(modf_(i + 1.0, n)), f);
}

fn sd_mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

// The offset keeps atan defined at the drop's exact center.
fn sd_angle(q: vec2f) -> f32 {
    return atan2(q.y, q.x + 1e-9) / TAU + 0.5;
}

fn sd_front(th: f32, r: f32) -> f32 {
    return r * (1.0 + 0.08 * params.crumple * (sd_noise(th * 7.0, 7.0) + 0.5 * sd_noise(th * 19.0, 19.0) - 0.75));
}

fn sd_height(q: vec2f, r0: f32, l: f32) -> f32 {
    let r = length(q);
    let th = sd_angle(q);
    let big_r = sd_front(th, r0);
    let d = max(r - big_r, 0.0);
    let comp = big_r / l * exp(-d / l);
    let t = comp / (1.0 + comp);
    let wob = 9.0 * sd_noise(th * 13.0, 13.0) + 7.0 * sd_noise(th * 37.0, 37.0);
    // Angular detail would crowd into spikes on a small disc.
    let folds = sin(d * 110.0 + wob) * sd_noise(th * 53.0 + d * 40.0, 53.0) * smoothstep(0.05, 0.3, big_r);
    let lip = 1.0 - exp(-d / 0.004);
    return 0.008 * t * lip * (1.0 + 1.4 * params.crumple * t * folds);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let a = vec2f(ratio, 1.0);
    let q = (uv - center) * a;
    let r = length(q);
    let dir = q / max(r, 1e-5);
    let th = sd_angle(q);
    let rmax = length(max(center, 1.0 - center) * a);

    let t = progress;
    let e = t * (1.4 - 0.4 * t);
    let l = 0.02 + 0.05 * e;
    // The lowest point of the noisy front still clears the farthest corner at the end.
    let r0 = e * (rmax + 0.02) / (1.0 - 0.06 * params.crumple);
    let big_r = sd_front(th, r0);

    let d = max(r - big_r, 0.0);
    let fall = exp(-d / l);
    let s = max(r - big_r * fall, 0.0);
    let comp = big_r / l * fall;
    let big_t = comp / (1.0 + comp);

    let eps = vec2f(0.0015, 0.0);
    let grad = vec2f(
        sd_height(q + eps, r0, l) - sd_height(q - eps, r0, l),
        sd_height(q + eps.yx, r0, l) - sd_height(q - eps.yx, r0, l)) / (2.0 * eps.x);
    let n = normalize(vec3f(-grad, 1.0));
    let diffuse = max(1.0 + 0.9 * (dot(n, LIGHT) - LIGHT.z), 0.0);
    // Subtracting the flat surface's highlight keeps the untouched skin exact.
    let spec = max(pow(max(dot(n, HALFWAY), 0.0), 50.0) - pow(HALFWAY.z, 50.0), 0.0);

    let suv = center + (dir * s - grad * 0.004) / a;
    let skin0 = from_color(sd_mirror(suv));
    let skin = vec4f(skin0.rgb * diffuse * (1.0 - 0.18 * big_t) + 0.6 * spec * big_t * skin0.a, skin0.a);

    let behind = max(big_r - r, 0.0);
    let calm = 1.0 - t;
    let k = behind * 70.0 - t * 38.0;
    let env = calm * calm * exp(-behind * 3.0);
    let wave = 0.009 * sin(k) + 0.005 * sin(k * 0.43 + 1.7);
    let water0 = to_color(sd_mirror(uv - dir * env * wave / a));
    let shadow = big_t * exp(-behind / 0.03) * (0.5 + 0.5 * dot(dir, LIGHT_XY));
    let water = vec4f(water0.rgb * (1.0 + 0.25 * env * cos(k) * dot(dir, LIGHT_XY)) * (1.0 - 0.45 * calm * shadow), water0.a);

    let m = mix(1.0, smoothstep(-AA, AA, r - big_r), smoothstep(0.0, 4.0 * AA, big_r));
    return mix(water, skin, m);
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
