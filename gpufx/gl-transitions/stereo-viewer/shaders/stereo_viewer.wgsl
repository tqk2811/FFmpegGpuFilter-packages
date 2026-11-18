// Port of StereoViewer.glsl from gl-transitions (author: Ted Schundler, license: BSD-2-Clause).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StereoViewer.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Blank value used while blending the cards.
const BLACK: vec4f = vec4f(0.0);
// Where no card is drawn the original leaves transparent black, which would be an empty frame
// between 0.48 and 0.52; this port shows an opaque near-black (#0d0d0d) there instead.
const EMPTY: vec4f = vec4f(0.051, 0.051, 0.051, 1.0);

fn in_corner(p0: vec2f, corner: vec2f, radius0: vec2f) -> bool {
    let radius = max(radius0, vec2f(1e-6));
    let axis = (vec2f(1.0) - corner) - corner;
    // Warp the point so we always test the bottom left corner with the circle centered on the origin.
    let p = (p0 - (corner + axis * radius)) * axis / radius;
    return (p.x > 0.0 && p.y > -1.0) || (p.y > 0.0 && p.x > -1.0) || dot(p, p) < 1.0;
}

fn rounded_mask(p: vec2f, corner_size: vec2f) -> bool {
    return in_corner(p, vec2f(0.0, 0.0), corner_size) && in_corner(p, vec2f(0.0, 1.0), corner_size)
        && in_corner(p, vec2f(1.0, 0.0), corner_size) && in_corner(p, vec2f(1.0, 1.0), corner_size);
}

// Screen blend mode, which comes closer to what the eye sees than linear blending.
fn screen(a: vec4f, b: vec4f) -> vec4f { return 1.0 - (1.0 - a) * (1.0 - b); }

// A value that, screened with itself, gives back c.
fn unscreen(c: vec4f) -> vec4f { return 1.0 - sqrt(max(1.0 - c, vec4f(0.0))); }

fn sample_card(p0: vec2f, corner_size: vec2f, scale: f32, incoming: bool) -> vec4f {
    let p = (p0 - 0.5) / scale + 0.5;
    if (!rounded_mask(p, corner_size)) { return BLACK; }
    return select(from_color(p), to_color(p), incoming);
}

// Moves the point around a pivot two units off screen, to one side (side = 1) or the other (side = -1).
fn cross_op(p: vec2f, s: vec2f, side: f32, angle: f32, ratio: f32) -> vec2f {
    var v = (p - 0.5) * s + vec2f(2.0 * side, 0.0);
    v = vec2f(cos(angle) * v.x - sin(angle) * v.y, sin(angle) * v.x + cos(angle) * v.y);
    v -= vec2f(2.0 * side, 0.0);
    return v * vec2f(1.0, ratio) + 0.5;
}

// Splits the clip and rotates one half up and one down around off-screen pivots.
fn cross_rotated(p: vec2f, a: f32, corner_size: vec2f, ratio: f32) -> vec4f {
    let angle = a * a / 2.4;
    let s = vec2f(1.0, 1.0 / ratio);
    let ca = sample_card(cross_op(p, s, 1.0, angle, ratio), corner_size, params.zoom, false);
    let cb = sample_card(cross_op(p, s, -1.0, angle, ratio), corner_size, params.zoom, false);
    return screen(unscreen(ca), unscreen(cb));
}

// The clip stays put, but this time two masks move.
fn cross_masked(p: vec2f, a: f32, corner_size: vec2f, ratio: f32) -> vec4f {
    let b = 1.0 - a;
    let angle = b * b / 2.4;
    let s = vec2f(1.0 / params.zoom, 1.0 / (params.zoom * ratio));
    let mask_a = rounded_mask(cross_op(p, s, 1.0, angle, ratio), corner_size);
    let mask_b = rounded_mask(cross_op(p, s, -1.0, angle, ratio), corner_size);
    if (!(mask_a || mask_b)) { return BLACK; }
    let img = unscreen(sample_card(p, corner_size, params.zoom, true));
    return screen(select(BLACK, img, mask_a), select(BLACK, img, mask_b));
}

fn stereo(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // The corner is warped to its size after mapping to the unit square.
    let corner_size = vec2f(params.corner_radius / ratio, params.corner_radius);
    if (progress < 0.1) {
        // Zoom out and round the corners.
        let a = progress / 0.1;
        return sample_card(uv, corner_size * a, 1.0 - a + params.zoom * a, false);
    } else if (progress < 0.48) {
        // Split the first clip apart.
        return cross_rotated(uv, (progress - 0.1) / 0.38, corner_size, ratio);
    } else if (progress < 0.9) {
        // Nothing until 0.52, then the masks uncover the second clip.
        return cross_masked(uv, (progress - 0.52) / 0.38, corner_size, ratio);
    }
    // Zoom back in and square the corners.
    let a = (1.0 - progress) / 0.1;
    return sample_card(uv, corner_size * a, 1.0 - a + params.zoom * a, true);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let c = stereo(uv, progress);
    return select(c, EMPTY, c.a <= 0.0);
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
