// Port of CurvedWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CurvedWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

// A gentle ease in and out, which does not linger at the ends.
fn ease(t: f32) -> f32 { return 0.5 * (t + t * t * (3.0 - 2.0 * t)); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var dir = vec2f(0.0, 1.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let w = 0.5 * (abs(dir.y) * ratio + abs(dir.x));
    let across = vec2f(-dir.y, dir.x);
    let d = dot(p, dir);
    // Where the pixel is across the frame, from -1 to 1: the edge is a single curve centered on the frame.
    let x = clamp(dot(p, across) / w, -1.0, 1.0);
    let s = max(params.smoothness, 0.001);
    // Each point of the edge runs on its own clock: the middle runs ahead, the sides catch up at the far side.
    let k = clamp(params.curvature, 0.0, 1.0) * min(1.0, w / e) * (1.0 - x * x);
    let t = progress + k * progress * (1.0 - progress);
    let travel = 2.0 * (e + s);
    let edge = -e - s + travel * ease(t);
    let side = -e - s + travel * ease(progress);
    let m = 1.0 - smoothstep(-s, s, d - edge);
    let lift = edge - side;
    let spread = 0.012 + 0.25 * lift;
    var to = to_color(uv);
    let caster = clamp((p + (edge - d) * dir) / vec2f(ratio, 1.0) + 0.5, vec2f(0.0), vec2f(1.0));
    let sh = params.shadow.a * sin(PI * progress) * exp(-max(edge - d, 0.0) / spread) * m * from_color(caster).a * to.a;
    to = vec4f(mix(to.rgb, params.shadow.rgb, sh), to.a);
    return mix(from_color(uv), to, m);
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
