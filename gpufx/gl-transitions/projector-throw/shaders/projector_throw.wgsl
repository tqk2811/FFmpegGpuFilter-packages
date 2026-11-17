// Port of ProjectorThrow.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ProjectorThrow.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn mirror(v: vec2f) -> vec2f { return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0))); }

// The projected picture, sampled with 8 taps on a disc of radius r (in its own coordinates),
// averaged premultiplied so transparent texels do not bleed into it.
fn projected(q: vec2f, r: vec2f) -> vec4f {
    var c = vec4f(0.0);
    for (var i = 0; i < 8; i++) {
        let a = f32(i) * 2.39996;
        let o = sqrt((f32(i) + 0.5) / 8.0) * vec2f(cos(a), sin(a));
        let t = to_color(mirror(q + o * r));
        c += vec4f(t.rgb * t.a, t.a);
    }
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a / 8.0); }
    return vec4f(0.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let fr = from_color(uv);
    let on = smoothstep(0.06, 0.26, p);
    let ambient = 1.0 - params.darkness * smoothstep(0.0, 0.2, p);
    let g = smoothstep(0.02, 1.0, p);
    let focus = 1.0 - smoothstep(0.15, 0.85, p);
    let size = mix(0.32, 1.0, g * (0.6 + 0.4 * g));
    let k = params.keystone * (1.0 - g);
    let cy = mix(0.58, 0.5, g);
    // Keystone: the picture is a trapezoid seen in perspective, its rows spaced wider where it is wider.
    let y = (uv.y - cy) / size + 0.5;
    let wy = max(1.0 - 0.5 * k + k * y, 0.05);
    let q = vec2f((uv.x - 0.5) / (size * wy) + 0.5, y * (1.0 + 0.5 * k) / wy);
    // Soft edges of the beam, in frame heights, sharp once in focus.
    let e = min((0.5 * size * wy - abs(uv.x - 0.5)) * ratio, size * min(y, 1.0 - y));
    let soft = 0.0015 + 0.035 * focus;
    let cov = mix(smoothstep(-soft, soft, e), 1.0, smoothstep(0.9, 1.0, p));
    let halo = 0.15 * focus * on * exp(-24.0 * max(-e, 0.0)) * (1.0 - cov);
    let d = q - 0.5;
    let gain = on * mix(1.25, 1.0, g) * (1.0 + focus * (0.15 - 1.2 * dot(d, d)));
    // The blur is round on the frame: picture coordinates stretch with the keystone.
    let r = params.blur * focus / (size * wy) * vec2f(1.0 / ratio, (1.0 - 0.25 * k * k) / wy);
    let pic = projected(q, r);
    let light = pic.rgb * gain * cov + halo;
    let screen = smoothstep(0.35, 0.95, p);
    let surface = mix(fr.rgb, vec3f(1.0), 0.35 + 0.65 * screen);
    let col = fr.rgb * ambient * (1.0 - cov * screen) + surface * light;
    // The picture of light shows even over a transparent scene.
    return vec4f(col, mix(max(fr.a, pic.a * cov * on), pic.a, cov * screen));
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
