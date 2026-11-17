// Port of Shred.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Shred.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash(n_in: f32) -> f32 {
    var n = fract(n_in * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = f32(max(params.strips, 1));
    let tilt = params.tilt;
    let stagger = params.stagger;
    // Strip width, in frame heights.
    let w = ratio / n;
    let q = vec2f(uv.x * ratio, uv.y);
    var color = to_color(uv);
    var cover = -1.0;
    var shade = 0.0;
    // Narrow strips tilt less, so they only reach over their neighbors.
    let max_tilt = min(tilt, 2.0 * w);
    for (var d = -3; d <= 3; d++) {
        let i = floor(uv.x * n) + f32(d);
        if (i < 0.0 || i > n - 1.0) { continue; }
        // About one strip in five starts right away.
        let delay = stagger * max(0.0, 1.25 * hash(i + 1.0) - 0.25);
        let speed = 1.0 + 0.5 * hash(i + 71.0);
        let t = clamp((progress - delay) / (1.0 - delay), 0.0, 1.0);
        let fall = (0.4 * t + 0.6 * t * t) * (1.0 + w * (0.5 + tilt)) * speed;
        let angle = max_tilt * (2.0 * hash(i + 37.0) - 1.0) * t;
        let lift = min(1.0, 8.0 * t);
        let gap = 0.06 * w * lift;
        let v = q - vec2f((i + 0.5) * w, 0.5 - fall);
        let ca = cos(angle);
        let sa = sin(angle);
        let l = vec2f(ca * v.x + sa * v.y, ca * v.y - sa * v.x);
        let edge = vec2f(0.5 * w - gap, 0.5) - abs(l);
        let so = abs(l - lift * vec2f(0.15 * w, -0.25 * w)) - vec2f(0.5 * w - gap, 0.5);
        shade = max(shade, lift * (1.0 - smoothstep(0.0, 0.5 * w, max(so.x, so.y))));
        if (min(edge.x, edge.y) >= 0.0 && fall > cover) {
            let p = vec2f((i + 0.5) * w + l.x, 0.5 + l.y);
            let img = from_color(vec2f(p.x / ratio, p.y));
            let cut = lift * (1.0 - smoothstep(0.0, 0.25 * w, edge.x));
            color = vec4f(img.rgb * (1.0 - 0.5 * params.shadow * cut), img.a);
            cover = fall;
        }
    }
    if (cover < 0.0) { color = vec4f(color.rgb * (1.0 - 0.6 * params.shadow * shade), color.a); }
    return color;
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
