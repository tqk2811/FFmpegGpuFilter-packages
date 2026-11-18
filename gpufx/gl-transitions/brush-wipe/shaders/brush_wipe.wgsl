// Port of BrushWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BrushWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn vnoise(p: vec2f) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2f(1.0, 0.0)), f.x),
        mix(hash(i + vec2f(0.0, 1.0)), hash(i + vec2f(1.0, 1.0)), f.x), f.y);
}

// Bristle streaks: fine across the stroke (t), long along it (u).
fn bristles(t: f32, u: f32, seed: f32) -> f32 {
    return 0.6 * vnoise(vec2f(t * 26.0 + seed, u * 1.3 + seed)) + 0.4 * vnoise(vec2f(t * 8.0 - seed, u * 0.7));
}

// One stroke: k its index, t the position across it (-1..1 is its core), u along it.
// Returns (coverage, wet streak shading).
fn stroke(k: f32, t: f32, u: f32, big_u: f32, n: f32, h: f32, progress: f32) -> vec2f {
    let dir = select(-1.0, 1.0, k - 2.0 * floor(k / 2.0) < 0.5);
    let x = u * dir;
    let dur = min(1.0, 1.8 / (n + 0.8));
    var start = 0.0;
    if (n > 1.0) { start = k * (1.0 - dur) / (n - 1.0); }
    var s = clamp((progress - start) / dur, 0.0, 1.0);
    s = mix(s, s * s * (3.0 - 2.0 * s), 0.7);
    let r = params.roughness;
    let lag = (0.15 + 0.6 * r) * h; // how far the longest bristles run ahead of the shortest
    let dry = (0.1 + 0.9 * r) * h; // length of the streaky, dry trail behind the head of the stroke
    // At the end even the shortest bristles are past the far edge with their dry trail.
    let head = mix(-big_u, big_u + lag + 0.3 * h + 1.15 * dry + 0.01, s);
    let b = bristles(t, k * 3.7, k * 17.0);
    let front = head - lag * (1.0 - b) - 0.3 * h * t * t;
    let streak = bristles(t * 1.7, x * 2.0 / h, k * 5.0 + 9.0);
    let along = clamp(((front - x) / (dry + 0.001) - 0.1 - 0.8 * streak) * 6.0, 0.0, 1.0);
    let fringe = 0.1 + 0.7 * r;
    let e = (abs(t) - 1.0) / fringe; // < 0 in the core of the stroke
    let reach = 0.5 + 0.5 * vnoise(vec2f(x * 2.5 / h, k * 7.0 + select(0.0, 3.0, t > 0.0)));
    let hair = clamp(bristles(t * 1.4, x * 3.0 / h, k * 11.0 + 3.0) * 2.0 - 0.5, 0.0, 1.0);
    let side = clamp((reach * hair - e) * 12.0 + 1.0, 0.0, 1.0);
    let cover = along * side;
    let wet = (1.0 - clamp((progress - start - dur) / 0.25, 0.0, 1.0)) * min(1.0, (1.0 - progress) * 6.0);
    return vec2f(cover, cover * wet * (bristles(t * 2.0, x * 2.0 / h, k) - 0.5));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = params.angle * PI / 180.0;
    let c = cos(a);
    let sn = sin(a);
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let u = c * q.x + sn * q.y; // along the strokes
    let v = -sn * q.x + c * q.y; // across them
    let big_u = 0.5 * (abs(c) * ratio + abs(sn));
    let big_v = 0.5 * (abs(sn) * ratio + abs(c));
    let n = max(1.0, floor(params.strokes + 0.5));
    let h = 2.0 * big_v / n;
    // Waves shared by the neighbouring strokes so that they always tile the frame.
    let amp = 0.12 * params.waviness * h;
    let w = v + amp * sin(u * 5.0 / big_u + v * 2.0 / h + 1.3) + 0.5 * amp * sin(u * 11.0 / big_u - v * 3.0 / h);
    let y = (big_v + 1.5 * amp - w) / (2.0 * big_v + 3.0 * amp) * n;
    let hh = (2.0 * big_v + 3.0 * amp) / n;
    let k = clamp(floor(y), 0.0, n - 1.0);
    var cover = 0.0;
    var shade = 0.0;
    for (var i = -1; i <= 1; i++) {
        let j = k + f32(i);
        if (j >= 0.0 && j <= n - 1.0) {
            let s = stroke(j, (y - j - 0.5) * 2.0, u, big_u, n, hh, progress);
            cover = max(cover, s.x);
            shade = mix(shade, s.y, s.x);
        }
    }
    let from_c = from_color(uv);
    let b = to_color(uv);
    let to_c = vec4f(min(b.rgb * (1.0 + 0.2 * shade), vec3f(1.0)), b.a);
    return mix(from_c, to_c, cover);
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
