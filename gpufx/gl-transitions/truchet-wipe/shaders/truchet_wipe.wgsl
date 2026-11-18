// Port of TruchetWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TruchetWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0012;
const LINE: f32 = 0.003;
const SHADOW: f32 = 0.025;
// Half width of the thin line a path is first drawn as, in tiles.
const STROKE: f32 = 0.08;

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(v.xyx * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn vnoise(v: vec2f) -> f32 {
    let i = floor(v);
    var f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2f(1.0, 0.0)), f.x),
        mix(hash12(i + vec2f(0.0, 1.0)), hash12(i + vec2f(1.0, 1.0)), f.x), f.y);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = max(floor(params.cells + 0.5), 1.0);
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let g = p * n + 0.5;
    let cell = floor(g);
    var q = fract(g);
    // Each tile is mirrored at random, so its two arcs link up with its neighbors' in two ways.
    if (hash12(cell + 17.0) > 0.5) { q.x = 1.0 - q.x; }
    // Distance to the nearest arc, in tiles.
    let d = min(abs(length(q) - 0.5), abs(length(q - 1.0) - 0.5));

    let big_t = clamp(length(p) / (0.5 * length(vec2f(ratio, 1.0))) + 0.4 * (vnoise(p * 3.0 + 4.0) - 0.5), 0.0, 1.0);
    let lag = 0.8 * clamp(params.spread, 0.0, 1.0);
    // Every point is fully covered at progress 0.95.
    let s = clamp((progress - lag * big_t) / (0.95 - lag), 0.0, 1.0);
    // In tiles: the paths are first drawn as thin lines, then the bands widen past the corners.
    let aa = AA * n;
    let k = clamp((s - 0.25) / 0.75, 0.0, 1.0);
    let w = STROKE * smoothstep(0.0, 0.3, s) + (0.5 + LINE * n + 3.0 * aa - STROKE) * k * k;
    // Signed distance to the edge of the bands (negative inside), in tiles.
    let e = d - w;

    let band = 1.0 - smoothstep(-2.0 * aa, 0.0, e);
    let gap = max(e + aa, 0.0);
    let fall = 1.0 - smoothstep(0.0, SHADOW * n, gap);
    let edge = max(0.8 * (1.0 - smoothstep(LINE * n, LINE * n + 2.0 * aa, gap)), 0.4 * fall * fall);
    let shade = clamp(params.outline, 0.0, 1.0) * smoothstep(0.0, STROKE, w) * edge;

    let a0 = from_color(uv);
    let a = vec4f(a0.rgb * (1.0 - shade), a0.a);
    let b = to_color(uv);
    // Mixed premultiplied, so transparent clips do not bleed their color.
    let o = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), band);
    if (o.a > 0.0) { return vec4f(o.rgb / o.a, o.a); }
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
