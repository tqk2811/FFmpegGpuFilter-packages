// Port of OutlineCrumble.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/OutlineCrumble.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn hash22(p: vec2f) -> vec2f {
    var p3 = fract(p.xyx * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

fn ratio() -> f32 { return globals.size.x / globals.size.y; }
fn to_uv(q: vec2f) -> vec2f { return vec2f(q.x / ratio(), q.y) / params.cells; }
fn seed_of(c: vec2f) -> vec2f { return c + 0.5 + 0.6 * (hash22(c) - 0.5); }

// Blurred color of the first clip around q, r cells wide, so grain does not fray the cracks.
fn soft(q: vec2f, r: f32) -> vec3f {
    let u = clamp(to_uv(q), vec2f(0.0), vec2f(1.0));
    let ex = vec2f(r / (params.cells * ratio()), 0.0);
    let ey = vec2f(0.0, r / params.cells);
    return (from_color(u + ex).rgb + from_color(u - ex).rgb + from_color(u + ey).rgb + from_color(u - ey).rgb) * 0.25;
}

// The piece that owns q: a Voronoi cell whose distance grows with color difference, so cracks
// snap to the outlines of the picture. z = distance to the crack, in cells.
fn owner(q: vec2f) -> vec3f {
    let col = soft(q, 0.25);
    let base = floor(q);
    var best = base;
    var s1 = q;
    var s2 = q;
    var d1 = 1e9;
    var d2 = 1e9;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let c = base + vec2f(f32(i), f32(j));
            let s = seed_of(c);
            let dq = q - s;
            let dc = col - from_color(clamp(to_uv(s), vec2f(0.0), vec2f(1.0))).rgb;
            let d = dot(dq, dq) + params.follow * min(dot(dc, dc), 0.04);
            if (d < d1) {
                d2 = d1; s2 = s1; d1 = d; s1 = s; best = c;
            } else if (d < d2) {
                d2 = d; s2 = s;
            }
        }
    }
    return vec3f(best, (d2 - d1) / (2.0 * length(s2 - s1) + 1e-3));
}

// Whether the piece of cell c can own q at all (a cheap test, without texture taps).
fn may_own(q: vec2f, c: vec2f) -> bool {
    let base = floor(q);
    if (abs(c.x - base.x) > 1.0 || abs(c.y - base.y) > 1.0) { return false; }
    var dmin = 1e9;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let dq = q - seed_of(base + vec2f(f32(i), f32(j)));
            dmin = min(dmin, dot(dq, dq));
        }
    }
    let dc = q - seed_of(c);
    return dot(dc, dc) <= dmin + params.follow * 0.04;
}

// Fall time of the piece of cell c, whose seed is s: top pieces go first, with some disorder.
fn local_time(c: vec2f, s: vec2f, progress: f32) -> f32 {
    let y = clamp(s.y / params.cells, 0.0, 1.0);
    let d = 0.75 * (1.0 - y) + 0.25 * hash22(c + 7.0).x;
    return (progress - 0.2 - 0.46 * d) / 0.32;
}

fn rot(a: f32) -> mat2x2f { return mat2x2f(cos(a), -sin(a), sin(a), cos(a)); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let cells = params.cells;
    let p = vec2f(uv.x * ratio(), uv.y) * cells;
    let own = owner(p);
    // Crack width scales with the frame height.
    let px = cells / 200.0;
    let crack = smoothstep(0.0, 0.1, progress - 0.1 * (1.0 - uv.y));
    let core = 1.0 - smoothstep(0.6 * px, 1.6 * px, own.z);
    let rim = (1.0 - smoothstep(1.6 * px, 3.2 * px, own.z)) - core;
    let from_c = from_color(uv);
    var col = vec4f(from_c.rgb * (1.0 - 0.85 * core * crack) * (1.0 + 0.2 * rim * crack), from_c.a);
    if (local_time(own.xy, seed_of(own.xy), progress) > 0.0) {
        let to = to_color(uv);
        col = vec4f(to.rgb * (1.0 - 0.5 * (1.0 - smoothstep(0.45, 1.0, progress))), to.a);
    }
    // Falling pieces; the most recently released one is on top.
    var top = 2.0;
    for (var j = -1; j <= 3; j++) {
        for (var i = -1; i <= 1; i++) {
            let c = floor(p) + vec2f(f32(i), f32(j));
            let s = seed_of(c);
            let t = local_time(c, s, progress);
            if (t <= 0.0 || t >= 1.0 || t >= top) { continue; }
            let loose = smoothstep(0.0, 0.18, t);
            let f = max(t - 0.15, 0.0) / 0.85;
            let g = f * f;
            let spin = hash22(c + 3.0).x - 0.5;
            let a = spin * (0.12 * loose + 1.6 * g);
            let scale = 1.0 - 0.6 * g;
            let d = rot(a) * (p - s - vec2f(0.0, -0.06 * loose - 1.7 * g)) / scale;
            let q = s + d;
            let qu = to_uv(q);
            if (qu.x < 0.0 || qu.x > 1.0 || qu.y < 0.0 || qu.y > 1.0 || !may_own(q, c)) { continue; }
            let o = owner(q);
            if (any(o.xy != c)) { continue; }
            let bev = 1.0 - smoothstep(0.0, 0.1, o.z);
            let n = rot(-a) * normalize(q - s + 1e-4);
            let fc = from_color(qu);
            let pc = fc.rgb * (1.0 + bev * 0.35 * n.y) * (1.0 - 0.5 * g);
            let edge = smoothstep(0.0, 1.5 * px / scale, o.z);
            col = mix(col, vec4f(pc, fc.a), (1.0 - smoothstep(0.8, 1.0, t)) * edge);
            // Only a piece that really covers the pixel hides the older ones behind it.
            if (edge > 0.5) { top = t; }
        }
    }
    return col;
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
