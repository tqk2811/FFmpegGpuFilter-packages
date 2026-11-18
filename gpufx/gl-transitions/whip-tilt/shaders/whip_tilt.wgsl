// Port of WhipTilt.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WhipTilt.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const SAMPLES: i32 = 24;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Folds the coordinates back into the clip, only a safety at the far edges.
fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// How far the camera has tilted at time t, from 0 to 1: slow start, whip in the middle, slow landing.
fn tilt(t: f32) -> f32 {
    let h = 1.0 - abs(2.0 * t - 1.0);
    let e = 0.5 * h * h * h * h;
    return select(1.0 - e, e, t < 0.5);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = progress;
    let ratio = globals.size.x / globals.size.y;
    let down = params.down != 0u;
    let h = 1.0 - abs(2.0 * p - 1.0);
    let shutter = params.blur * 0.25 * h * h;
    // The clips are two faces of a drum around the camera that meet edge to edge at the angle of the field of view.
    let half_fov = mix(15.0, 45.0, params.perspective) * PI / 180.0;
    let dist = 0.5 / tan(half_fov);
    var q = (uv - 0.5) * vec2f(ratio, 1.0);
    if (down) { q.y = -q.y; }
    let jitter = hash(uv * vec2f(ratio, 1.0) * 731.0);
    var color = vec3f(0.0);
    var weight = vec3f(0.0);
    var alpha = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        let s = (f32(i) + jitter) / f32(SAMPLES) - 0.5;
        let t = clamp(p + s * shutter, 0.0, 1.0);
        let a = 2.0 * half_fov * tilt(t);
        // Zoom in just enough that the faces always cover the frame, wherever their edge is.
        let r = q * cos(half_fov) / cos(half_fov - a);
        let d0 = vec2f(r.y * cos(a) + dist * sin(a), dist * cos(a) - r.y * sin(a));
        let b = a - 2.0 * half_fov;
        let d1 = vec2f(r.y * cos(b) + dist * sin(b), dist * cos(b) - r.y * sin(b));
        // The ray leaves the drum through the nearest face.
        let incoming = d1.y > d0.y;
        let d = select(d0, d1, incoming);
        var hit = dist / d.y * vec2f(r.x, d.x);
        if (down) { hit.y = -hit.y; }
        let suv = mirror(hit / vec2f(ratio, 1.0) + 0.5);
        let col = select(from_color(suv), to_color(suv), incoming);
        // Red trails behind and blue leads along the motion: the channels split with the speed.
        let w = max(vec3f(1.0 - 4.0 * params.chroma * s, 1.0, 1.0 + 4.0 * params.chroma * s), vec3f(0.0));
        color += col.rgb * col.a * w;
        weight += col.a * w;
        alpha += col.a;
    }
    return vec4f(color / max(weight, vec3f(1e-5)), alpha / f32(SAMPLES));
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
