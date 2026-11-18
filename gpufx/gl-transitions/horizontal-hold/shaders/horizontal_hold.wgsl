// Port of HorizontalHold.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HorizontalHold.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn slip_count() -> f32 { return max(f32(params.slips), 1.0); }

// The picture stream at x: copies of the first clip, then of the second, with a bar between them.
fn stream(x: f32, y: f32, unsync: f32) -> vec4f {
    let bar = params.bar_width;
    let period = 1.0 + bar;
    let n = floor(x / period);
    let xm = x - n * period;
    let q = vec2f(min(xm, 1.0), y);
    var c = select(from_color(q), to_color(q), n >= floor(0.5 * slip_count() + 0.5));
    // Distance to the nearest bar, negative inside it.
    let d = min(xm, 1.0 - xm);
    let g = max(1.0 - d / 0.05, 0.0);
    c = vec4f(c.rgb + 0.3 * unsync * g * g * c.a, c.a);
    let soft = min(0.012 * unsync, 0.5 * bar) + 1e-5;
    return mix(params.bar_color, c, clamp(d / soft, 0.0, 1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let period = 1.0 + params.bar_width;
    let shear = params.shear;
    // The sync error grows then fades; the slip is its integral, a whole number of periods.
    let t = min(progress / 0.88, 1.0);
    let err = 16.0 * t * t * (1.0 - t) * (1.0 - t);
    let slip = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
    let u = clamp((progress - 0.74) / 0.26, 0.0, 1.0);
    let lock = u * (1.0 - u) * (1.0 - u);
    let tilt = -0.5 * max(shear, 0.5) * lock * sin(9.42478 * u);
    let unsync = min(err + 3.0 * lock, 1.0);
    let ripple = 0.012 * sin(uv.y * 9.0 + progress * 40.0) + 0.005 * sin(uv.y * 31.0 - progress * 70.0);
    let x = uv.x + period * (slip_count() * slip + shear * err * (1.0 - uv.y) + tilt * (1.0 - uv.y)) + err * ripple;
    let blur = 0.002 * err * slip_count();
    var c = stream(x, uv.y, unsync);
    if (blur > 0.0) {
        for (var i = 0; i < 4; i++) {
            c += stream(x + blur * (f32(i) - 1.5), uv.y, unsync);
        }
        c /= 5.0;
    }
    c = vec4f(c.rgb * (1.0 - unsync * (0.1 + 0.08 * sin(uv.y * 480.0))), c.a);
    return c;
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
