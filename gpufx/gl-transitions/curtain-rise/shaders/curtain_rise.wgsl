// Port of CurtainRise.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CurtainRise.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let p = progress;
    let f = 1.0 - (1.0 - p) * (1.0 - p) * (1.0 - p);
    let e = mix(p, p * p * (3.0 - 2.0 * p), 0.4);
    let s = params.sag * f;
    let lift = mix(-0.01, 1.0 + params.sag + 0.08, e);
    // Across a swag, -1 and 1 at the cords; fewer swags in a portrait frame.
    let n = max(1.0, floor(params.swags * sqrt(ratio / 1.78) + 0.5));
    let u = fract(uv.x * n) * 2.0 - 1.0;
    let bump = 1.0 - u * u;
    let hem = lift - s * bump;
    let aa = 0.002 + 0.004 * f;
    let inside = smoothstep(hem - aa, hem + aa, uv.y);
    var c = vec4f(0.0);
    if (inside > 0.0) {
        // q goes from 0 at the top rod to 1 at the hem; the whole height of fabric is gathered into it.
        let h = max(1.0 - max(hem, 0.0), 1e-4);
        let q = clamp((1.0 - uv.y) / h, 0.0, 1.0);
        // Ruffles merge as the curtain shortens, so none gets thinner than 2% of the frame.
        let m = min(max(1.0, floor(params.ruffles + 0.5)), h / 0.02);
        let a = 2.0 * PI * m * q;
        let g = 0.85 * f * min(1.0, 0.3 + 5.0 * (1.0 - h)) * (0.6 + 0.4 * bump);
        let v = clamp(q + g * sin(a) / (2.0 * PI * m), 0.0, 1.0);
        let pull = 0.25 * f * q * q * sin(PI * u) / (PI * n);
        c = from_color(vec2f(uv.x - pull, 1.0 - v));
        let slope = 2.5 * g * cos(a);
        let diffuse = (1.0 - 0.35 * slope) / sqrt(1.0 + slope * slope);
        let crease = 0.5 + 0.5 * sin(a);
        var light = mix(1.0, diffuse * (1.0 - 0.45 * crease * crease), shading * g);
        light += 0.18 * shading * g * smoothstep(0.4, 1.0, -cos(a));
        let depth = f * q * (0.3 + 0.7 * q);
        light *= 1.0 - shading * depth * (0.35 * u * u + 0.5 * exp(-(1.0 - abs(u)) * 14.0));
        light *= 1.0 - 0.35 * shading * f * exp(-(uv.y - hem) * 120.0);
        c = vec4f(c.rgb * light, c.a);
        if (inside >= 1.0) { return c; }
    }
    var to = to_color(uv);
    let below = max(hem - uv.y, 0.0);
    let shadow = 0.6 * shading * exp(-below * 22.0) * smoothstep(0.0, 0.05, lift) * (1.0 - smoothstep(1.0, 1.06, lift - s));
    to = vec4f(to.rgb * (1.0 - shadow), to.a);
    return mix(to, c, inside);
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
