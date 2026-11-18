// Port of StereoViewer.glsl from gl-transitions (author: Ted Schundler, license: BSD 2-Clause).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StereoViewer.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.
//
// Difference from the original: where no card is drawn the original leaves the frame
// transparent, so the whole frame is empty from progress 0.48 to 0.52 and nearly empty
// around it. Here the cards are laid over `back_color` instead
// (`#00000000` gives back the original transparent frame).

const NONE: vec4f = vec4f(0.0); // where no card is drawn: transparent, then `back_color`

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn in_corner(p0: vec2f, corner: vec2f, radius: vec2f) -> bool {
    let axis = (vec2f(1.0) - corner) - corner;
    // Warp the point so the test is always the bottom left corner with its circle at the origin.
    let p = (p0 - (corner + axis * radius)) * axis / max(radius, vec2f(1e-6));
    return (p.x > 0.0 && p.y > -1.0) || (p.y > 0.0 && p.x > -1.0) || dot(p, p) < 1.0;
}

fn test_rounded_mask(p: vec2f, corner_size: vec2f) -> bool {
    return in_corner(p, vec2f(0.0, 0.0), corner_size) && in_corner(p, vec2f(0.0, 1.0), corner_size)
        && in_corner(p, vec2f(1.0, 0.0), corner_size) && in_corner(p, vec2f(1.0, 1.0), corner_size);
}

// Screen blend mode, closer to what the device shows than a linear blend.
fn screen(a: vec4f, b: vec4f) -> vec4f { return 1.0 - (1.0 - a) * (1.0 - b); }
// The value that, screened with itself, gives back `c`.
fn unscreen(c: vec4f) -> vec4f { return 1.0 - sqrt(max(1.0 - c, vec4f(0.0))); }

fn sample_corners_from(p0: vec2f, corner_size: vec2f) -> vec4f {
    let p = (p0 - 0.5) / params.zoom + 0.5;
    if (!test_rounded_mask(p, corner_size)) { return NONE; }
    return unscreen(from_color(p));
}

fn sample_corners_to(p0: vec2f, corner_size: vec2f) -> vec4f {
    let p = (p0 - 0.5) / params.zoom + 0.5;
    if (!test_rounded_mask(p, corner_size)) { return NONE; }
    return unscreen(to_color(p));
}

// Used while zooming: an extra zoom amount, and no unscreen.
fn simple_corners_from(p0: vec2f, corner_size: vec2f, zoom_amt: f32) -> vec4f {
    let p = (p0 - 0.5) / (1.0 - zoom_amt + params.zoom * zoom_amt) + 0.5;
    if (!test_rounded_mask(p, corner_size)) { return NONE; }
    return from_color(p);
}

fn simple_corners_to(p0: vec2f, corner_size: vec2f, zoom_amt: f32) -> vec4f {
    let p = (p0 - 0.5) / (1.0 - zoom_amt + params.zoom * zoom_amt) + 0.5;
    if (!test_rounded_mask(p, corner_size)) { return NONE; }
    return to_color(p);
}

fn rotate2d(angle: f32) -> mat3x3f {
    let s = sin(angle);
    let c = cos(angle);
    return mat3x3f(c, s, 0.0, -s, c, 0.0, 0.0, 0.0, 1.0);
}
fn translate2d(x: f32, y: f32) -> mat3x3f { return mat3x3f(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -x, -y, 1.0); }
fn scale2d(x: f32, y: f32) -> mat3x3f { return mat3x3f(x, 0.0, 0.0, 0.0, y, 0.0, 0.0, 0.0, 1.0); }

// Split the first image and rotate one half up and one down around pivots off screen.
fn get_cross_rotated(p3: vec3f, a: f32, corner_size: vec2f, ratio: f32) -> vec4f {
    let angle = a * a / 2.4;
    let center_and_scale = translate2d(-0.5, -0.5) * scale2d(1.0, ratio);
    let unscale_and_uncenter = scale2d(1.0, 1.0 / ratio) * translate2d(0.5, 0.5);
    let slide_left = translate2d(-2.0, 0.0);
    let slide_right = translate2d(2.0, 0.0);
    let rotate = rotate2d(angle);
    let op_a = center_and_scale * slide_right * rotate * slide_left * unscale_and_uncenter;
    let op_b = center_and_scale * slide_left * rotate * slide_right * unscale_and_uncenter;
    let ca = sample_corners_from((op_a * p3).xy, corner_size);
    let cb = sample_corners_from((op_b * p3).xy, corner_size);
    return screen(ca, cb);
}

// The second image stays put while two masks move.
fn get_cross_masked(p3: vec3f, a: f32, corner_size: vec2f, ratio: f32) -> vec4f {
    let b = 1.0 - a;
    let angle = b * b / 2.4;
    let center_and_scale = translate2d(-0.5, -0.5) * scale2d(1.0, ratio);
    let unscale_and_uncenter = scale2d(1.0 / params.zoom, 1.0 / (params.zoom * ratio)) * translate2d(0.5, 0.5);
    let slide_left = translate2d(-2.0, 0.0);
    let slide_right = translate2d(2.0, 0.0);
    let rotate = rotate2d(angle);
    let op_a = center_and_scale * slide_right * rotate * slide_left * unscale_and_uncenter;
    let op_b = center_and_scale * slide_left * rotate * slide_right * unscale_and_uncenter;
    let mask_a = test_rounded_mask((op_a * p3).xy, corner_size);
    let mask_b = test_rounded_mask((op_b * p3).xy, corner_size);
    if (mask_a || mask_b) {
        let img = sample_corners_to(p3.xy, corner_size);
        return screen(select(NONE, img, mask_a), select(NONE, img, mask_b));
    }
    return NONE;
}

fn cards(p: vec2f, progress: f32, ratio: f32) -> vec4f {
    let p3 = vec3f(p, 1.0);
    // The corner is warped to its size once mapped to (1, 1).
    let corner_size = vec2f(params.corner_radius / ratio, params.corner_radius);
    if (progress < 0.1) {
        // 0.0 - 0.1: zoom out and round the corners.
        let a = progress / 0.1;
        return simple_corners_from(p, corner_size * a, a);
    } else if (progress < 0.48) {
        // 0.1 - 0.48: split the first image apart.
        return get_cross_rotated(p3, (progress - 0.1) / 0.38, corner_size, ratio);
    } else if (progress < 0.9) {
        // 0.48 - 0.52: no card (`back_color` here, transparent in the original).
        // 0.52 - 0.9: unmask the second image.
        return get_cross_masked(p3, (progress - 0.52) / 0.38, corner_size, ratio);
    }
    // 0.9 - 1.0: zoom back in and square the corners.
    let a = (1.0 - progress) / 0.1;
    return simple_corners_to(p, corner_size * a, a);
}

fn transition(q: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let c = cards(q, progress, ratio);
    // Lay the cards over `back_color` (the original leaves the rest transparent).
    return c + params.back_color * (1.0 - clamp(c.a, 0.0, 1.0));
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
