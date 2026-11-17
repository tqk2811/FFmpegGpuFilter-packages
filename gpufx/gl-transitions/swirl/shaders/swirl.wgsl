// Port of Swirl.glsl from gl-transitions (author: Sergey Kosarevsky, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Swirl.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture. `center` is given y down, as the
// other gpufx packages, and flipped here.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const TAU: f32 = 6.283185307179586;
const ZOOM: f32 = 0.12;
// Spread of the motion blur, as a fraction of the swirl's speed.
const BLUR: f32 = 0.05;
const TAPS: i32 = 12;

// Folds the coordinates back into the frame, so the picture stays filled without smearing its border.
fn mirrored(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return mix(m, 2.0 - m, step(vec2f(1.0), m));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    // The swirl eases in and out and is exactly 0 at both ends.
    let s = sin(PI * progress);
    let amount = s * s;
    // Its speed, for the motion blur, also 0 at both ends.
    let speed = PI * sin(TAU * progress);
    let reveal = smoothstep(0.3, 0.7, progress);

    let aspect = vec2f(globals.size.x / globals.size.y, 1.0);
    var d = (uv - center) * aspect;
    let x = clamp(length(d) / max(params.radius, 1e-3), 0.0, 1.0);
    let falloff = (1.0 - x) * (1.0 - x);
    let twist = params.strength * TAU * falloff;
    let angle = twist * amount;
    // Capped so the blur taps never spread apart into visible streaks.
    let spread = clamp(twist * speed * BLUR, -1.2, 1.2);
    d *= 1.0 - ZOOM * amount * falloff;

    var col = vec4f(0.0);
    var total = 0.0;
    for (var i = 0; i < TAPS; i++) {
        let k = f32(i) / f32(TAPS - 1) - 0.5;
        let w = 1.0 - abs(k);
        let a = angle + spread * k;
        let c = cos(a);
        let sn = sin(a);
        let q = mirrored(center + vec2f(c * d.x - sn * d.y, sn * d.x + c * d.y) / aspect);
        col += mix(from_color(q), to_color(q), reveal) * w;
        total += w;
    }
    return col / total;
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
