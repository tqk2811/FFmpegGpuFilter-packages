// Port of PixelStretch.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PixelStretch.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash(n_in: f32) -> f32 {
    var n = fract(n_in * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

// Smooth max with a compact support: exactly max(x, y) when they are k apart.
fn smax(x: f32, y: f32, k: f32) -> f32 {
    let h = max(k - abs(x - y), 0.0) / k;
    return max(x, y) + h * h * k * 0.25;
}

// Position s along the sweep (0 to 1 across the frame) to a frame coordinate.
fn at(uv: vec2f, s0: f32, s: f32, d: vec2f, ext: f32) -> vec2f {
    return clamp(uv + d * (s - s0) * ext, vec2f(0.0), vec2f(1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let jitter = params.jitter;
    let d = normalize(params.direction + vec2f(1e-6, 0.0));
    let ext = abs(d.x) + abs(d.y);
    let s = 0.5 + dot(uv - 0.5, d) / ext;
    // Rows across the streaks (about one per pixel line), in frame heights.
    let nrm = vec2f(-d.y, d.x);
    let t = dot((uv - 0.5) * vec2f(ratio, 1.0), nrm);
    let row = floor(t * 540.0);
    let clump = floor(t * 60.0);
    let rnd = 0.6 * hash(row + 17.0) + 0.4 * hash(clump + 311.0);
    let p = progress;
    let k = params.softness + 1e-4;
    // The line starts and ends at rest just beyond the frame, past its soft edge.
    let margin = k + 0.002;
    let a = mix(-margin, 1.0 + margin, mix(p, p * p * (3.0 - 2.0 * p), 0.5));
    // The streaks are longest when the line crosses the middle and vanish at the edges.
    let h = clamp(4.0 * a * (1.0 - a), 0.0, 1.0);
    let len = params.stretch * h * (1.0 - 0.6 * jitter * rnd);
    let split = 0.02 * params.chroma * h;
    // Ahead of the line the first clip is intact; behind it, each pixel repeats the pixel at the line.
    let fr = from_color(at(uv, s, smax(s, a + split, k), d, ext));
    let fg = from_color(at(uv, s, smax(s, a, k), d, ext));
    let fb = from_color(at(uv, s, smax(s, a - split, k), d, ext));
    var streak = vec4f(fr.r, fg.g, fb.b, fg.a);
    let behind = step(s, a);
    streak = vec4f(streak.rgb * (1.0 + 0.06 * jitter * h * (hash(row * 3.0 + 5.0) - 0.5) * behind), streak.a);
    let w = smoothstep(len - k, len + k, a - s);
    return mix(streak, to_color(uv), w);
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
