// Port of StarWipe.glsl from gl-transitions (author: Ben Lucas, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StarWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const STAR_ANGLE: f32 = 1.2566370614359172;

fn rotate(v: vec2f, theta: f32) -> vec2f {
    let c = cos(theta);
    let s = sin(theta);
    return vec2f(c * v.x - s * v.y, s * v.x + c * v.y);
}

fn in_star(uv: vec2f, center: vec2f, radius: f32) -> bool {
    let ratio = globals.size.x / globals.size.y;
    // Unlike the original, measured in square pixels so the star is not stretched.
    let q = rotate((uv - center) * vec2f(ratio, 1.0), params.star_rotation * STAR_ANGLE);
    let theta = atan2(q.y, q.x) + PI;
    let r = rotate(q, -STAR_ANGLE * (floor(theta / STAR_ANGLE) + 0.5));
    let slope = 0.3;
    if (r.y > 0.0) { return radius + r.x * slope > r.y; }
    return -radius - r.x * slope < r.y;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // `star_center` is given y down.
    let center = vec2f(params.star_center.x, 1.0 - params.star_center.y);
    // Unlike the original (radius 0 to 1 in texture units, which left the corners of a wide
    // frame uncovered until the jump at progress 1), the radius is measured in square pixels
    // and grows to 0.8 times the distance of the farthest corner, where the star covers the
    // frame (0.73 to 0.76 of it for the usual frame shapes).
    let far = length(max(center, 1.0 - center) * vec2f(ratio, 1.0)) * 0.8;
    let bt = params.border_thickness;
    let scaled = ((2.0 * bt + 1.0) * progress - bt) * far;
    if (in_star(uv, center, scaled)) { return to_color(uv); }
    if (in_star(uv, center, scaled + bt * far)) { return params.border_color; }
    return from_color(uv);
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
