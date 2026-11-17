// Port of XorWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/XorWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SHARP: f32 = 300.0;

fn ease(x_in: f32) -> f32 {
    let x = clamp(x_in, 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

fn seed(i: i32) -> vec2f {
    if (i == 0) { return vec2f(0.3, 0.38); }
    if (i == 1) { return vec2f(0.74, 0.62); }
    if (i == 2) { return vec2f(0.52, 0.18); }
    if (i == 3) { return vec2f(0.18, 0.8); }
    return vec2f(0.86, 0.22);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let rim = params.rim;
    let a = vec2f(ratio, 1.0);
    let p = uv * a;
    var par = 1.0;
    var shade = 0.0;
    var line = 0.0;
    // The disc count stays odd so the parity ends on the second clip.
    for (var i = 0; i < 5; i++) {
        let s = seed(i) * a;
        // The margin pushes the edge and its shade past the farthest corner.
        let r = (length(max(s, a - s)) + 0.01 + rim) * ease((progress - f32(i) * 0.12) / 0.52);
        let d = r - length(p - s);
        // A disc fades in from radius 0 so it adds nothing at progress 0.
        let born = min(r * SHARP, 1.0);
        let c = clamp(d * SHARP + 0.5, 0.0, 1.0) * born;
        par *= 1.0 - 2.0 * c;
        let k = 1.0 - smoothstep(0.0, min(rim, 0.5 * r) + 1e-4, d);
        shade += c * k * k;
        line += max(1.0 - abs(d) * SHARP * 0.5, 0.0) * born;
    }
    var col = mix(from_color(uv), to_color(uv), 0.5 - 0.5 * par);
    let env = 4.0 * progress * (1.0 - progress);
    var rgb = col.rgb * (1.0 - 0.35 * min(shade, 1.0) * env);
    rgb = mix(rgb, vec3f(1.0), 0.35 * min(line, 1.0) * env);
    return vec4f(rgb, col.a);
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
