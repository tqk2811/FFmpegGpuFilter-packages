// Port of Cleave.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Cleave.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const EDGE: f32 = 0.0025;
// How far into each half the bunching reaches, in frame heights.
const FALLOFF: f32 = 0.11;

fn zigzag(v: f32) -> f32 {
    return abs(fract(v) - 0.5) * 4.0 - 1.0;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let p = progress;
    let sz = vec2f(ratio, 1.0);
    // Snapped to an axis so that the wedge runs from one edge of the frame to the opposite one.
    let dr = params.direction;
    var dd = vec2f(0.0, select(-1.0, 1.0, dr.y > 0.0));
    if (abs(dr.x) > abs(dr.y)) { dd = vec2f(sign(dr.x), 0.0); }
    let nn = vec2f(-dd.y, dd.x);
    let q = (uv - 0.5) * sz;
    let len = abs(dd.x) * ratio + abs(dd.y);
    let half_width = 0.5 * (abs(dd.y) * ratio + abs(dd.x));
    let t = dot(q, dd) + 0.5 * len;
    let c = dot(q, nn);
    let x = abs(c);
    let side = select(1.0, -1.0, c < 0.0);

    let a = clamp(p / 0.62, 0.0, 1.0);
    let drive = a * a * (3.0 - 2.0 * a);
    let tip = len * drive;
    let b = clamp((p - 0.5) / 0.5, 0.0, 1.0);
    let apart = b * b;
    let k = tan(radians(params.opening));

    let wedge = k * max(tip - t, 0.0);
    // The halves only come apart where the wedge has split them, leaning out as they fall away.
    let w = wedge + (half_width + 0.02 + 0.3 * (len - t)) * apart * clamp(1.0 + (tip - t) / EDGE, 0.0, 1.0);

    // The second clip's leading edge rides on the wedge point.
    let to0 = to_color((q + dd * len * (1.0 - drive)) / sz + 0.5);
    let shadow = shading * 0.7 * exp(-max(w - x, 0.0) * cos(radians(params.opening)) / 0.035) * (1.0 - apart) * clamp(1.0 + (w - x) / EDGE, 0.0, 1.0);
    let to = vec4f(to0.rgb * (1.0 - shadow), to0.a);

    // Part of the push bunches the picture up against the wedge, the rest slides it away rigidly;
    // the bunching relaxes once the halves are free.
    let d = max(x - w, 0.0);
    let bunch = wedge * params.squash * (1.0 - apart);
    let fall = exp(-d / FALLOFF);
    let qf = (t - 0.5 * len) * dd + side * (d + bunch * (1.0 - fall)) * nn;
    let fr = from_color(qf / sz + 0.5);

    let ridge = bunch / FALLOFF * fall;
    let lip = 1.0 - smoothstep(0.0, 0.012, d);
    var light = 1.0 + shading * (0.5 * lip * min(ridge, 1.0) - 0.3 * min(ridge, 1.5) * (1.0 - lip) * (1.0 - 0.5 * fall));

    let grow = clamp(p / 0.08, 0.0, 1.0);
    let crack_len = 0.2 * grow;
    let ahead = t - tip;
    if (ahead > 0.0 && ahead < crack_len) {
        let xc = smoothstep(0.0, 0.02, ahead) * (0.006 * zigzag(t * 21.0) + 0.0025 * zigzag(t * 57.0 + 0.3));
        let taper = 1.0 - ahead / crack_len;
        let width = 0.0015 + 0.004 * taper;
        light *= 1.0 - 0.75 * (1.0 - smoothstep(width, width + EDGE, abs(c - xc))) * taper * grow;
    }
    let from_lit = vec4f(fr.rgb * light, fr.a);

    // The cut fades in while the wedge is thinner than EDGE, so nothing shows at the start.
    let m = mix(1.0, clamp(0.5 + 0.5 * (x - w) / EDGE, 0.0, 1.0), clamp(w / EDGE, 0.0, 1.0));
    return mix(to, from_lit, m);
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
