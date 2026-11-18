// Port of BrickCollapse.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BrickCollapse.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const G: f32 = 14.0;
const PULL: f32 = 0.16;
const EDGE: f32 = 0.0012;

fn ratio() -> f32 { return globals.size.x / globals.size.y; }

fn hash(p: vec2f) -> f32 {
    var q = fract(p.xyx * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// GLSL's mat2(c, -s, s, c) * v.
fn rot(a: f32, v: vec2f) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * v.x + s * v.y, -s * v.x + c * v.y);
}

fn course_offset(r: f32, bw: f32) -> f32 {
    return (r - 2.0 * floor(r / 2.0)) * 0.5 * bw;
}

// When brick i of course r starts to fall, -1 for the pulled brick.
fn fall_start(r: f32, i: f32, bh: f32, bw: f32, x0: f32, reach: f32) -> f32 {
    let d = abs((i + 0.5) * bw + course_offset(r, bw) - x0);
    if (r < 0.5 && d < 0.5 * bw) { return -1.0; }
    // The bricks the pulled one held form a steep wedge; outside it, the collapse spreads sideways.
    let v = 0.5 * bw + 0.3 * r * bh * min(ratio(), 1.0);
    let far = max(reach - v, bw);
    // The latest start that still lets the brick, grown and spun, fall out of the frame before the end.
    let deadline = 0.95 - sqrt((r + 3.0) * bh / G);
    let excess = max(d - v, 0.0);
    let jitter = 0.05 * (hash(vec2f(i, r) + 3.7) - 0.5) * step(0.001, excess);
    return mix(PULL * 0.7 + r * bh * 0.2, deadline, clamp(excess / far + jitter, 0.0, 1.0));
}

fn rect_cover(q: vec2f, half_size: vec2f, soft: f32) -> f32 {
    let d = half_size - abs(q);
    return clamp(min(d.x, d.y) / soft + 0.5, 0.0, 1.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = ratio();
    let bh = min(ratio, 1.0) / clamp(f32(params.rows), 1.0, 12.0);
    let bw = 2.1 * bh;
    let hs = vec2f(0.5 * bw, 0.5 * bh);
    let pp = vec2f(uv.x * ratio, uv.y);
    let x0 = (clamp(floor(clamp(params.origin, 0.0, 1.0) * ratio / bw), 0.0, max(floor(ratio / bw - 0.5), 0.0)) + 0.5) * bw;
    let reach = max(x0, ratio - x0);
    let k = clamp(params.shading, 0.0, 1.0);
    let appear = smoothstep(0.0, 0.06, progress);

    var ao = 0.0;
    var shadow = 0.0;
    var wall = vec4f(0.0);
    var wall_cov = 0.0;
    var fall = vec4f(0.0);
    var fall_cov = 0.0;
    var fall_grow = 0.0;

    for (var j = 0; j < 48; j++) {
        let r = f32(j);
        if (r * bh >= 1.0) { break; }
        // Bricks only fall, so a course well below the point can't reach it.
        if (pp.y - (r + 0.5) * bh > bw) { continue; }
        let off = course_offset(r, bw);
        for (var n = -1; n < 2; n++) {
            let i = floor((pp.x - off) / bw) + f32(n);
            let t0 = fall_start(r, i, bh, bw, x0, reach);
            let home = vec2f((i + 0.5) * bw + off, (r + 0.5) * bh);
            var q: vec2f;
            var s: f32;
            var grow = 1.0;
            var shadow_offset = vec2f(0.0);
            if (t0 < 0.0) {
                s = clamp(progress / PULL, 0.0, 1.0);
                q = pp - home + vec2f(0.0, 1.1 * bh * s * s);
            } else {
                s = max(progress - t0, 0.0);
                let spin = (hash(vec2f(i, r) + 1.3) - 0.5) * 2.2 * G * s * s;
                let drift = sign(x0 - home.x) * 0.25 * G * s * s * bh;
                // The bricks topple forward, toward the eye, and cast their shadow on what is behind.
                grow = 1.0 + 0.7 * s;
                q = rot(spin, pp - home - vec2f(drift, -G * s * s)) / grow;
                shadow_offset = rot(spin, vec2f(0.25, -0.45)) * bh * min(4.0 * s, 1.0) / grow;
            }
            let falling = step(0.0001, s);
            let moving = smoothstep(0.0, 0.05, s);
            let e = min(hs.x - abs(q.x), hs.y - abs(q.y));
            if (falling > 0.0) {
                let soft = 0.15 * bh * min(4.0 * s, 1.0) + EDGE;
                shadow = max(shadow, rect_cover(q - shadow_offset, hs, soft / grow) * min(8.0 * s, 1.0));
            }
            // Standing bricks overlap by a hair so that rounding leaves no seam.
            if (e < -1e-4 - 0.5 * EDGE * moving / grow) {
                ao = max(ao, exp(e / (0.25 * bh)) * appear * (1.0 - moving));
                continue;
            }
            let src = home + q;
            // The frame cuts the wall's edge bricks: their part outside it is never drawn.
            var b = from_color(select(uv, vec2f(src.x / ratio, src.y), falling > 0.0));
            let in_frame = clamp(min(src, vec2f(ratio, 1.0) - src) * grow / EDGE + 1.0, vec2f(0.0), vec2f(1.0));
            let l = q / vec2f(bw, bh) + 0.5;
            let lit = min(s * 8.0, 1.0);
            let joint = 1.0 - smoothstep(0.0, 0.004 + 0.004 * lit, e);
            var rgb = b.rgb * (1.0 - 0.45 * k * joint * appear);
            rgb *= 1.0 + 0.25 * k * lit * (l.y - l.x);
            rgb *= 1.0 - 0.35 * k * falling * min(s * 4.0, 1.0) * (1.0 - l.y);
            b = vec4f(rgb, b.a);
            if (falling > 0.0) {
                let a = mix(1.0, clamp(e * grow / EDGE + 0.5, 0.0, 1.0), moving) * in_frame.x * in_frame.y;
                // The brick that has grown most is nearest to the eye.
                if (grow > fall_grow) {
                    let nc = a + fall_cov * (1.0 - a);
                    if (nc > 0.0) { fall = mix(fall, b, a / nc); }
                    fall_cov = nc;
                    fall_grow = grow;
                } else {
                    let w = a * (1.0 - fall_cov);
                    fall_cov += w;
                    if (w > 0.0) { fall = mix(fall, b, w / fall_cov); }
                }
            } else {
                wall = b;
                wall_cov = 1.0;
            }
        }
    }
    var c = to_color(uv);
    c = vec4f(c.rgb * (1.0 - 0.55 * k * ao), c.a);
    c = mix(c, wall, wall_cov);
    c = vec4f(c.rgb * (1.0 - 0.45 * k * shadow), c.a);
    return mix(c, fall, fall_cov);
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
