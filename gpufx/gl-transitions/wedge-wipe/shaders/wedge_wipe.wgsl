// Port of WedgeWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WedgeWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Measured in square pixels, so the angles are not stretched. The center is given y down.
    let c = vec2f(params.center.x, 1.0 - params.center.y);
    let q = (uv - c) * vec2f(ratio, 1.0);
    let a = radians(params.angle);
    // Local frame: y along the starting direction, x across it (the wedge is symmetric).
    let p = vec2f(abs(q.x * cos(a) - q.y * sin(a)), q.x * sin(a) + q.y * cos(a));
    let spread = PI * progress;
    let hand = vec2f(max(sin(spread), 0.0), cos(spread));
    // Signed distance to the wedge: the nearest hand, negative inside.
    let l = length(p);
    let d = length(p - hand * clamp(dot(p, hand), 0.0, l)) * sign(hand.y * p.x - hand.x * p.y);
    // The soft edge slides from outside to inside the hands, so the ends are exact.
    let s = max(params.smoothness, 0.001);
    let m = 1.0 - smoothstep(0.0, s, d + s * (1.0 - progress));
    return mix(from_color(uv), to_color(uv), m);
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
