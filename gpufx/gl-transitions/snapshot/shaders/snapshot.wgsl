// Port of Snapshot.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Snapshot.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// How much smaller the photo gets before it drops.
const SHRINK: f32 = 0.24;
const RADIUS: f32 = 0.008;
const AA: f32 = 0.0015;

fn rounded_box(q: vec2f, b: vec2f, r: f32) -> f32 {
    let d = abs(q) - b + r;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

fn premultiply(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let p = progress;
    let tilt = params.tilt;
    let asp = vec2f(ratio, 1.0);
    let q = (uv - 0.5) * asp;
    let half_image = 0.5 * asp;
    let half_card = half_image + params.border;
    let k = smoothstep(0.05, 0.4, p);
    let t = clamp((p - 0.3) / 0.7, 0.0, 1.0);
    let fall = t * t;
    let s = 1.0 - SHRINK * k;
    let a = -tilt * (0.12 * k + 0.88 * fall);
    let bound = (abs(sin(tilt)) * half_card.x + abs(cos(tilt)) * half_card.y) * (1.0 - SHRINK);
    let lift = 0.035 * k * (1.0 - fall);
    let mid = vec2f(0.08 * fall, lift - (0.5 + bound + 0.1) * fall);
    let rad = RADIUS * k;
    let ca = cos(a);
    let sa = sin(a);
    let unrotate = mat2x2f(ca, -sa, sa, ca);
    var col = to_color(uv);
    let sh = params.shadow * k;
    if (sh > 0.0) {
        let rs = unrotate * (q - mid - vec2f(0.012, -0.022) * k) / s;
        let ds = rounded_box(rs, half_card, rad) * s;
        let blur = 0.035 * s;
        col = vec4f(col.rgb * (1.0 - sh * (1.0 - smoothstep(-blur, blur, ds))), col.a);
    }
    col = premultiply(col);
    let r = unrotate * (q - mid) / s;
    let d_card = rounded_box(r, half_card, rad) * s;
    let d_image = rounded_box(r, half_image, 0.0) * s;
    // The edges are pushed out by one antialiasing width, so the photo covers the full frame at the start.
    let card_cover = clamp(1.5 - d_card / AA, 0.0, 1.0);
    let image_cover = clamp(1.5 - d_image / AA, 0.0, 1.0);
    // The picture replaces what is behind it; the border is laid over the second clip, which shows through a translucent border.
    let photo = premultiply(from_color(clamp(r / asp + 0.5, vec2f(0.0), vec2f(1.0))));
    let paper = premultiply(params.border_color);
    let card = mix(paper + col * (1.0 - paper.a), photo, image_cover);
    col = mix(col, card, card_cover);
    if (col.a <= 0.0) { return vec4f(0.0); }
    // The flash only adds light: a quick bloom to white that fades as the photo comes out.
    let fl = params.flash * smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.05, 0.3, p));
    return vec4f(1.0 - (1.0 - col.rgb / col.a) * (1.0 - fl), col.a);
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
