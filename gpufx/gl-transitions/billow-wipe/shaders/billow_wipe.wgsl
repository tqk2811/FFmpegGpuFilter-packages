// Port of BillowWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BillowWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Radius of a curl, relative to the distance between the curls.
const SIZE: f32 = 0.47;
// How far the curls are already wound when they enter the frame, in radians.
const START: f32 = 1.5;
// How far before the frame the eyes of the curls start, in curl radii.
const ENTER: f32 = 0.5;
// Share of the transition the curls take to start winding.
const RAMP: f32 = 0.15;
// Width of the lit lip on the incoming side and of the shadow on the outgoing side, in frame heights.
const LIP: f32 = 0.02;
const SHADOW: f32 = 0.035;
// Half width of the antialiased interface, in frame heights.
const AA: f32 = 0.0015;

// Folds coordinates back into the frame, so a curl reaching past the edge never smears its border pixels.
fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress;

    var dir = vec2f(0.0, -1.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    // Across the front, so that (side, -dir) keeps the orientation of the frame.
    let side = vec2f(-dir.y, dir.x);
    let aspect = vec2f(ratio, 1.0);
    let p = (uv - 0.5) * aspect;
    // Half extent of the frame along the travel, in frame heights.
    let ext = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let sp = max(params.spacing, 0.01);
    let rad = SIZE * sp;

    // The front sweeps from just before the frame, its curls not wound yet, to fully past it, curls included.
    let e = mix(t, t * t * (3.0 - 2.0 * t), 0.3);
    let front = mix(-ext - max(ENTER * rad, SHADOW + AA), ext + rad + 0.02, e);
    let slide = params.drift * t;
    // u across the front, v behind it (on the incoming side).
    let u = dot(p, side) - slide;
    let v = front - dot(p, dir);
    // The curl of this column, centered on the front.
    let cu = floor(u / sp + 0.5) * sp;
    let q = vec2f(u - cu, v);
    let r = length(q);
    // Away from the front, the clips are untouched.
    if (v < -max(rad, SHADOW)) { return from_color(uv); }
    if (v > max(rad, LIP)) { return to_color(uv); }

    // Each curl winds both clips into a spiral: still at its rim, turning most at its eye, tighter as it travels.
    let x = clamp(r / rad, 0.0, 1.0);
    let s = 1.0 - x * x * (3.0 - 2.0 * x);
    let fall = s * s;
    // The curls start winding as they enter the frame.
    let turns = (START + params.winding * t) * smoothstep(0.0, RAMP, t);
    let a = turns * fall;
    let c = cos(a);
    let sn = sin(a);
    let w = vec2f(c * q.x + sn * q.y, c * q.y - sn * q.x);

    let src = mirror(uv + ((w.x - q.x) * side - (w.y - q.y) * dir) / aspect);
    var outgoing = from_color(src);
    var incoming = to_color(src);

    // The interface is where the unwound point crosses the front; its distance on screen comes from the gradient of w.y.
    let dfall = -12.0 * s * x * (1.0 - x) / rad;
    var qn = vec2f(0.0);
    if (r > 0.0) { qn = q / r; }
    let grad = vec2f(-sn, c) - w.x * turns * dfall * qn;
    let phi = w.y / max(length(grad), 0.1);
    let m = smoothstep(-AA, AA, phi);

    // A lit lip on the incoming side and a soft shadow on the outgoing side, along the whole interface.
    let lip = 1.0 - smoothstep(0.0, LIP, phi);
    let shadow = 1.0 - smoothstep(0.0, SHADOW, -phi);
    incoming = vec4f(incoming.rgb + (1.0 - incoming.rgb) * 0.25 * lip, incoming.a);
    outgoing = vec4f(outgoing.rgb * (1.0 - 0.3 * shadow * shadow), outgoing.a);

    // Mixed premultiplied, so transparent clips do not bleed their color.
    let col = mix(vec4f(outgoing.rgb * outgoing.a, outgoing.a), vec4f(incoming.rgb * incoming.a, incoming.a), m);
    if (col.a > 0.0) { return vec4f(col.rgb / col.a, col.a); }
    return vec4f(0.0);
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
