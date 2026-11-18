// Port of DominoFall.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/DominoFall.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0015;

fn knock_part() -> f32 {
    return clamp(params.knock, 0.05, 1.0);
}

// The fall of slat j, 0 standing to 1 lying flat.
fn fall_time(j: f32, n: f32, progress: f32) -> f32 {
    let k = knock_part();
    let d = 1.0 / (1.0 + (n - 1.0) * k);
    return clamp((progress - j * k * d) / d, 0.0, 1.0);
}

fn fall_angle(t: f32) -> f32 {
    return 0.5 * PI * t * (0.2 + 0.8 * t);
}

// Where slat j is seen at the point (xc, y) of the frame: (x across the slat, height on it, its
// fall, its angle), with a negative fall where it is not seen (its height can exceed 1, above its top).
fn slat_point(j: f32, n: f32, w: f32, xc: f32, y: f32, progress: f32) -> vec4f {
    let none = vec4f(0.0, 0.0, -1.0, 0.0);
    if (j < 0.0 || j > n - 1.0) { return none; }
    let t = fall_time(j, n, progress);
    if (t >= 1.0) { return none; }
    let a = fall_angle(t);
    let c = cos(a);
    let s = sin(a);
    // A camera in front of the slat goes down to the level of the hinge as the slat falls,
    // so that the slat ends edge-on.
    let eye = vec3f((j + 0.5) * w, 0.5 * c, -1.0 / max(params.perspective, 0.01));
    let dir = vec3f(xc, y, 0.0) - eye;
    let den = dir.z * c - dir.y * s;
    if (den <= 0.0) { return none; }
    let r = (eye.y * s - eye.z * c) / den;
    let hit = eye + r * dir;
    let h = hit.y * c + hit.z * s;
    if (r <= 0.0 || h < 0.0) { return none; }
    let side = clamp(params.lean, 0.0, 1.0) * w * min(t / knock_part(), 1.0) * h;
    return vec4f(hit.x - side - j * w, h, t, a);
}

// Draws slat j, seen at pt, over color; front is where the next slat, which may stand in front of it, is seen.
fn draw_slat(color: vec4f, j: f32, pt: vec4f, front: vec4f, w: f32, ratio: f32) -> vec4f {
    let t = pt.z;
    if (t < 0.0) { return color; }
    let shading = params.shading;
    let s = sin(pt.w);
    let d = min(pt.x, w - pt.x);
    var m: f32;
    if (t <= 0.0) {
        // Standing still: the slats tile the frame exactly.
        m = select(0.0, 1.0, d >= 0.0 && pt.y <= 1.0);
    } else {
        let e = EDGE * min(10.0 * t, 1.0) * (1.0 + max(params.perspective, 0.0) * pt.y * s);
        m = clamp(d / e + 0.5, 0.0, 1.0) * clamp((1.0 - pt.y) * max(cos(pt.w), 0.05) / e + 0.5, 0.0, 1.0);
    }
    if (m <= 0.0) { return color; }
    let sx = (j * w + clamp(pt.x, 0.0, w)) / ratio;
    let img = from_color(vec2f(select(sx, 1.0 - sx, params.reverse != 0u), min(pt.y, 1.0)));
    var shade = 1.0 - shading * s * (0.4 + 0.6 * pt.y);
    if (front.z >= 0.0 && front.z < t && front.x < 0.0) {
        let reach = clamp(1.0 - (front.y - 1.0) / 0.05, 0.0, 1.0);
        shade *= 1.0 - 0.6 * shading * exp(front.x / (0.15 * w)) * reach * min((t - front.z) / knock_part(), 1.0);
    }
    return mix(color, vec4f(img.rgb * shade, img.a), m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = f32(max(params.count, 1));
    let w = ratio / n;
    let xc = select(uv.x, 1.0 - uv.x, params.reverse != 0u) * ratio;
    let col = clamp(floor(xc / w), 0.0, n - 1.0);

    let b = to_color(uv);
    let t0 = fall_time(col, n, progress);
    var color = vec4f(b.rgb * (1.0 - 2.4 * params.shading * t0 * (1.0 - t0) * exp(-40.0 * uv.y)), b.a);

    // The slats are seen narrower as they fall, and their tops lean over the next column at most:
    // the slat before this column, behind, then the one of this column.
    let cur = slat_point(col, n, w, xc, uv.y, progress);
    color = draw_slat(color, col - 1.0, slat_point(col - 1.0, n, w, xc, uv.y, progress), cur, w, ratio);
    color = draw_slat(color, col, cur, slat_point(col + 1.0, n, w, xc, uv.y, progress), w, ratio);
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
