// Port of Halftone.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Halftone.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Dot radius, in cells, of a halftone printing this color (darker is bigger).
fn dot_radius(c: vec4f) -> f32 {
    let shade = 1.0 - dot(c.rgb, vec3f(0.299, 0.587, 0.114));
    return mix(0.1, 0.74, sqrt(clamp(shade, 0.0, 1.0))) * c.a;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let h = smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
    let t = (progress - 0.3) / 0.4;
    let a = radians(params.angle);
    let rot = mat2x2f(cos(a), sin(a), -sin(a), cos(a));
    let scale = vec2f(ratio, 1.0) * params.dots / min(ratio, 1.0);
    let g = rot * ((uv - 0.5) * scale);
    let base = floor(g - 0.5) + 0.5;
    let pixel = select(to_color(uv), from_color(uv), progress < 0.5);
    // The dots of the 4 nearest cells may overlap this point: keep the one it is deepest in.
    var best = 1e3;
    var ink = pixel;
    for (var i = 0; i < 4; i++) {
        let center = base + vec2f(f32(i % 2), f32(i / 2));
        let cuv = (center * rot) / scale + 0.5;
        let cf = from_color(cuv);
        let ct = to_color(cuv);
        let m = smoothstep(0.0, 1.0, clamp(2.5 * t - 1.5 * cuv.x, 0.0, 1.0));
        // At h = 0 the dots cover their whole cell with the picture itself.
        let r = mix(0.78, mix(dot_radius(cf), dot_radius(ct), m), h);
        let sd = length(g - center) - r;
        if (sd < best) {
            best = sd;
            ink = mix(pixel, mix(cf, ct, m), h);
        }
    }
    return mix(params.paper, ink, 1.0 - smoothstep(-0.06, 0.06, best));
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
