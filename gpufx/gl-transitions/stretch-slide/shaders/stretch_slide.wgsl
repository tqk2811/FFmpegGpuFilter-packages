// Port of StretchSlide.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StretchSlide.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let stretch = params.stretch;
    let bounce = params.bounce;
    let dl = length(params.direction);
    var d = vec2f(-1.0, 0.0);
    if (dl > 1e-6) { d = params.direction / dl; }
    let n = vec2f(-d.y, d.x);
    // s: position along the slide, from 0 (trailing side) to 1 (leading side).
    let ext = abs(d.x) + abs(d.y);
    let q = uv - 0.5;
    let s = 0.5 + dot(q, d) / ext;
    let t = progress;
    // The slide accelerates into the landing (a smoothstep when there is no bounce).
    let land = mix(1.0, 0.5, bounce);
    let m = 3.0 * bounce;
    let x = clamp(t / land, 0.0, 1.0);
    let e = x * x * (3.0 - 2.0 * x) + m * x * x * (x - 1.0);
    // Then a damped spring, starting at the landing speed, that comes to rest exactly at the end.
    let w = 2.5 * PI;
    let u = clamp((t - land) / max(1.0 - land, 1e-4), 0.0, 1.0);
    let osc = m * (1.0 - land) / (land * w) * exp(-u) * sin(w * u) * (1.0 - u) * (1.0 - u);
    // Past the landing the spring stretches the second clip along the slide, then squashes it.
    let len = e + max(osc, 0.0);
    let bulge = 1.0 - e + 3.0 * max(-osc, 0.0);
    let g = 1.0 + 0.6 * stretch * bulge;
    var pt = q + d * (s / max(len, 1e-4) - s) * ext;
    pt -= n * dot(pt, n) * (1.0 - 1.0 / g);
    let b = to_color(mirror(pt + 0.5));
    let l = 1.0 + 4.0 * stretch * e;
    let k = clamp(1.6 * stretch * e, 0.0, 0.8);
    let y = max(s - e, 0.0) / l;
    // Invert y = (1 + k) v - k v^2.
    let v = 2.0 * y / ((1.0 + k) + sqrt((1.0 + k) * (1.0 + k) - 4.0 * k * y));
    let a = from_color(mirror(q + d * (v - s) * ext + 0.5));
    return select(a, b, s < len || t >= land);
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
