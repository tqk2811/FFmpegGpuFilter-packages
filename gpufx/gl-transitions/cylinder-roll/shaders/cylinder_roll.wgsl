// Port of CylinderRoll.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CylinderRoll.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SAMPLES: i32 = 24;
// The half angle of the drum seen in the frame height, at full curvature.
const MAX_ANGLE: f32 = 1.1;
// Distance from the camera to the drum's axis, in drum radii.
const DIST: f32 = 2.6;
// How much the horizontal lines arc away from the middle, per frame height squared.
const ARC: f32 = 0.12;

fn hash(c: vec2f) -> f32 {
    var q = fract(c * vec2f(0.1031, 0.1030));
    q += dot(q, q.yx + 33.33);
    return fract((q.x + q.y) * q.x);
}

fn fold(v: f32) -> f32 {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

fn strip(x: f32, v: f32) -> vec4f {
    let downward = params.downward != 0u;
    if (select((v < 0.0), (v > 1.0), downward)) {
        return to_color(vec2f(x, fold(select(v + 1.0, v - 1.0, downward))));
    }
    return from_color(vec2f(x, fold(v)));
}

// Angle on the drum seen at the projected height c (the drum has a radius of 1).
fn angle_at(c0: f32) -> f32 {
    let lim = 0.98 / sqrt(DIST * DIST - 1.0);
    let c = clamp(c0, -lim, lim);
    return asin(c * DIST / sqrt(1.0 + c * c)) - atan(c);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let downward = params.downward != 0u;
    let p = progress;
    let h = 1.0 - abs(2.0 * p - 1.0);
    let e = 0.5 * h * (0.1 + 0.9 * h * h);
    let roll = select(1.0 - e, e, p < 0.5);
    let h3 = h * h * h;
    let peak = h3 * h3;

    let bend = params.curvature * select(h * h * (3.0 - 2.0 * h), h * (2.0 - h), p < 0.5);
    let phi = MAX_ANGLE * bend + 1e-4;
    let arc_k = ARC * bend;
    let edge_y = sin(phi) / (DIST - cos(phi));

    let n = 2.0 * uv - 1.0;
    let xr = n.x * ratio;
    let yn = n.y * (1.0 + arc_k * xr * xr);
    let theta = angle_at(yn * edge_y);
    // Nearer parts of the drum look wider: the drum is made wide enough to fill the frame's corners.
    let theta_corner = angle_at((1.0 + arc_k * ratio * ratio) * edge_y);
    let width = (DIST - 1.0) / (DIST - cos(theta));
    let zoom = (DIST - cos(theta_corner)) / (DIST - 1.0);
    let x = 0.5 + 0.5 * n.x / (zoom * width);
    let facing = (DIST * cos(theta) - 1.0) / sqrt(1.0 + DIST * DIST - 2.0 * DIST * cos(theta));
    let light = mix(1.0, clamp(facing, 0.0, 1.0), params.shading);

    // Position on the strip (the frame height when flat), rolling the first clip away.
    let v = 0.5 * (theta / phi + 1.0) + select(-roll, roll, downward);
    let len = 0.5 * params.blur * peak;
    let split = params.chroma * peak;
    let jitter = hash(uv * 1000.0);
    var color = vec3f(0.0);
    var weight = vec3f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        let t = (f32(i) + jitter) / f32(SAMPLES) - 0.5;
        let img = strip(x, v + t * len);
        let w = vec3f(max(1.0 - 4.0 * split * t, 0.0), 1.0, max(1.0 + 4.0 * split * t, 0.0));
        color += img.rgb * img.a * w;
        weight += img.a * w;
        alpha += img.a;
    }
    color = color / max(weight, vec3f(1e-5));
    return vec4f(color * light, alpha / f32(SAMPLES));
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
