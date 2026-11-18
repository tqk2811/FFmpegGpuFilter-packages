// Port of EchoSlide.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/EchoSlide.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const EDGE: f32 = 0.002;
const MAX_ECHOES: i32 = 7;

fn ease_in_out(t: f32) -> f32 { return t * t * (3.0 - 2.0 * t); }

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// Coverage of the part of the frame past an edge at x, anti-aliased only inside the frame.
fn past(s: f32, x: f32) -> f32 {
    if (x <= 0.0) { return 1.0; }
    if (x >= 1.0) { return 0.0; }
    return clamp((s - x) / EDGE + 0.5, 0.0, 1.0);
}

fn edge_at(t: f32) -> f32 { return ease_in_out(clamp(t, 0.0, 1.0)); }

// Step j between the two clips: an echo of the first fading toward an echo of the second.
fn echo_step(uv: vec2f, s: f32, shift: vec2f, j: f32, t0: f32, lag: f32, n: f32) -> vec4f {
    let e0 = edge_at(t0 + j * lag);
    let e1 = edge_at(t0 + (j + 1.0) * lag);
    let a = from_color(mirror(uv - shift * e0));
    let b = to_color(mirror(uv - shift * (e1 - 1.0)));
    var c = mix(b, a, pow((j + 0.5) / n, 0.5 + 2.0 * clamp(params.decay, 0.0, 1.0)));
    c = vec4f(c.rgb * (1.0 - 0.25 * exp(-max(e1 - s, 0.0) / 0.02) * min((e1 - e0) / 0.02, 1.0)), c.a);
    return c;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let dl = length(params.direction);
    var d = vec2f(1.0, 0.0);
    if (dl > 1e-6) { d = params.direction / dl; }
    let ext = abs(d.x) + abs(d.y);
    let shift = d * ext;
    let s = 0.5 + dot(uv - 0.5, d) / ext;
    let n = clamp(f32(params.echoes), 1.0, f32(MAX_ECHOES));
    let tr = clamp(params.trail, 0.05, 0.6);
    let lag = tr / n;
    let t0 = progress * (1.0 + tr) - tr;
    let e_in = edge_at(t0);
    let e_out = edge_at(t0 + tr);
    let w_in = 1.0 - past(s, e_in);
    let w_out = past(s, e_out);
    let w_gap = max(1.0 - w_in - w_out, 0.0);
    var c = vec4f(0.0);
    if (w_gap > 0.0) {
        var jf = 0.0;
        for (var k = 1; k < MAX_ECHOES; k++) {
            let m = f32(k);
            if (m >= n) { break; }
            jf += past(s, edge_at(t0 + m * lag));
        }
        let j = floor(jf);
        c = echo_step(uv, s, shift, j, t0, lag, n);
        if (jf > j) { c = mix(c, echo_step(uv, s, shift, j + 1.0, t0, lag, n), jf - j); }
        c *= w_gap;
    }
    if (w_in > 0.0) { c += w_in * to_color(mirror(uv - shift * (e_in - 1.0))); }
    if (w_out > 0.0) { c += w_out * from_color(mirror(uv - shift * e_out)); }
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
