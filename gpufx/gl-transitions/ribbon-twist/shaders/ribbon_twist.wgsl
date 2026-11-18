// Port of RibbonTwist.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/RibbonTwist.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.002;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let vertical = params.vertical != 0u;
    let persp = params.perspective;
    let spread = params.spread;
    // q.x: along the ribbon, the way the twist travels; q.y: across it.
    let q = select(uv, vec2f(1.0 - uv.y, uv.x), vertical);
    let half_size = select(0.5, 0.5 * ratio, vertical);
    let t = smoothstep(0.0, 1.0, (progress * (1.0 + spread) - q.x) / spread);
    // The visible face (first clip on the front, second on the back) and its angle.
    let front = t < 0.5;
    let angle = PI * select(t - 1.0, t, front);
    let c = cos(angle);
    let s = sin(angle);
    // w: screen position across the ribbon, -1 to 1 at rest; v: the matching point of the face.
    let w = 2.0 * q.y - 1.0;
    let den = c + persp * w * s;
    if (den <= 0.0) { return params.back_color; }
    let v = w / den;
    if (abs(v) >= 1.0) { return params.back_color; }
    // Soft edges while twisting (sharp at rest).
    let edge = max(EDGE * min(1.0, 20.0 * abs(s)), 1e-4);
    let top = c / (1.0 - persp * s);
    let bottom = -c / (1.0 + persp * s);
    let cover = clamp(min(top - w, w - bottom) * half_size / edge, 0.0, 1.0);
    var p = vec2f(q.x, 0.5 + 0.5 * v);
    if (vertical) { p = vec2f(p.y, 1.0 - p.x); }
    let img = select(to_color(p), from_color(p), front);
    let lambert = clamp(c - 0.25 * s, 0.0, 1.0);
    let color = vec4f(img.rgb * mix(1.0 - params.shading, 1.0, lambert), img.a);
    return mix(params.back_color, color, cover);
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
