// Port of TriangleFlip.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TriangleFlip.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const SQRT3: f32 = 1.7320508075688772;
const EDGE: f32 = 0.0012;
// Distance of the eye from the sheet, in triangle sides.
const EYE: f32 = 3.0;
// How high a turning triangle lifts off the sheet, in triangle sides.
const LIFT: f32 = 0.3;
const LIGHT: vec3f = vec3f(-0.4, 0.45, 0.8);

fn ease_in_out(t: f32) -> f32 { return mix(t, t * t * (3.0 - 2.0 * t), 0.75); }

// Signed distance (positive inside) from p to an equilateral triangle centered on its centroid,
// with inradius r, pointing up (o = 1) or down (o = -1), measured on screen when the triangle
// is squeezed by k along b (turned about the axis a).
fn tri_dist_squeezed(p: vec2f, r: f32, o: f32, a: vec2f, b: vec2f, k: f32) -> f32 {
    let n0 = vec2f(0.0, -o);
    let n1 = vec2f(0.5 * SQRT3, 0.5) * o;
    let n2 = vec2f(-0.5 * SQRT3, 0.5) * o;
    let d0 = (r - dot(p, n0)) * k / length(vec2f(dot(n0, a) * k, dot(n0, b)));
    let d1 = (r - dot(p, n1)) * k / length(vec2f(dot(n1, a) * k, dot(n1, b)));
    let d2 = (r - dot(p, n2)) * k / length(vec2f(dot(n2, a) * k, dot(n2, b)));
    return min(d0, min(d1, d2));
}

fn tri_dist(p: vec2f, r: f32, o: f32) -> f32 {
    return tri_dist_squeezed(p, r, o, vec2f(1.0, 0.0), vec2f(0.0, 1.0), 1.0);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn aa(d: f32, e: f32) -> f32 { return clamp(d / max(2.0 * e, 1e-6) + 0.5, 0.0, 1.0); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let frame = vec2f(globals.size.x / globals.size.y, 1.0);
    let pos = uv * frame;
    let h = 1.0 / max(f32(params.rows), 1.0);
    let side = 2.0 * h / SQRT3;
    let inradius = side / (2.0 * SQRT3);
    let e1 = vec2f(side, 0.0);
    let e2 = vec2f(0.5 * side, h);
    // Skewed lattice coordinates: each cell holds an upward and a downward triangle.
    let lv = pos.y / h;
    let cell = floor(vec2f(pos.x / side - 0.5 * lv, lv));
    let eye = EYE * side;

    // The center option is given y down.
    let origin = vec2f(params.center.x, 1.0 - params.center.y) * frame;
    let farthest = max(origin, frame - origin);
    let reach = max(length(farthest), 1e-4);
    let st = clamp(params.stagger, 0.0, 0.9);
    let sh = clamp(params.shading, 0.0, 1.0);
    let l = normalize(LIGHT);
    let hv = normalize(l + vec3f(0.0, 0.0, 1.0));
    let ax0 = vec2f(0.0, 1.0);
    let ax1 = vec2f(0.5 * SQRT3, 0.5);
    let ax2 = vec2f(-0.5 * SQRT3, 0.5);

    var w_from = 0.0;
    var w_to = 0.0;
    var hole = 0.0;
    var shadow = 0.0;
    var c1 = vec4f(0.0);
    var c2 = vec4f(0.0);
    var m1 = 0.0;
    var m2 = 0.0;
    var z1 = -1e9;
    var z2 = -1e9;

    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            for (var k = 0; k < 2; k++) {
                let nc = cell + vec2f(f32(i), f32(j));
                let o = select(-1.0, 1.0, k == 0);
                let base = nc.x * e1 + nc.y * e2;
                let ctr = base + select(2.0, 1.0, k == 0) * (e1 + e2) / 3.0;
                let q = pos - ctr;

                let toward = ctr - origin;
                let dist = length(toward);
                let dir = select(vec2f(1.0, 0.0), toward / max(dist, 1e-9), dist > 1e-5);
                let delay = clamp(dist / reach, 0.0, 1.0);
                let t = clamp((progress - delay * st) / (1.0 - st), 0.0, 1.0);

                if (t <= 0.0 || t >= 1.0) {
                    let m = aa(tri_dist(q, inradius, o), EDGE);
                    if (t <= 0.0) { w_from += m; } else { w_to += m; }
                    continue;
                }

                // Turn about the median of the triangle that lies most across the wave,
                // so the triangle rolls over away from the origin of the wave.
                var a = ax0;
                if (abs(dot(ax1, dir)) < abs(dot(a, dir))) { a = ax1; }
                if (abs(dot(ax2, dir)) < abs(dot(a, dir))) { a = ax2; }
                var b = vec2f(-a.y, a.x);
                if (dot(b, dir) > 0.0) { b = -b; }

                let ang = PI * ease_in_out(t);
                let ca = cos(ang);
                let sa = sin(ang);
                let lift = LIFT * side * sa;

                // The hole it leaves shows the second clip in its shade, the first right as it
                // takes off so its edges stay seamless.
                let mh = aa(tri_dist(q, inradius, o), EDGE);
                let k2 = smoothstep(0.0, 0.2, t);
                w_from += mh * (1.0 - k2);
                w_to += mh * k2;
                hole = max(hole, mh * sa);
                let sq = q + LIGHT.xy / LIGHT.z * lift;
                let sk = 0.3 + 0.7 * abs(ca);
                let sp = dot(sq, a) * a + dot(sq, b) / sk * b;
                let sd = tri_dist_squeezed(sp, inradius, o, a, b, sk);
                let blur = 0.004 + 0.3 * lift;
                shadow = max(shadow, 0.5 * sa * (1.0 - smoothstep(-blur, blur, -sd)));

                // Ray from the eye above the center through this point to the turned plane,
                // spanned by a and (b cos, sin) and lifted by lift.
                let qb = dot(q, b);
                let den = eye * ca + sa * qb;
                if (abs(den) < 1e-6) { continue; }
                let s = (eye - lift) * ca / den;
                if (s <= 0.0) { continue; }
                let hz = eye * (1.0 - s);
                let alpha = s * dot(q, a);
                let beta = s * qb * ca + (hz - lift) * sa;
                let lp = alpha * a + beta * b;
                let d = tri_dist_squeezed(lp, inradius, o, a, b, max(abs(ca), 1e-3)) / s;
                let m = aa(d, EDGE);
                if (m <= 0.0) { continue; }

                let front = ca > 0.0;
                var col: vec4f;
                if (front) {
                    col = from_color(mirror((ctr + lp) / frame));
                } else {
                    col = to_color(mirror((ctr + alpha * a - beta * b) / frame));
                }
                let n = vec3f(-sa * b, ca) * select(-1.0, 1.0, front);
                let lit = dot(n, l) / l.z;
                var rgb = col.rgb * (1.0 - sh * (1.0 - clamp(lit, 0.0, 1.0)) * 0.65 + sh * 0.15 * max(lit - 1.0, 0.0));
                let spec = pow(max(dot(n, hv), 0.0), 60.0);
                rgb += sh * sa * (0.45 * spec + 0.15 * (1.0 - smoothstep(0.0, 3.0 * EDGE, d))) * col.a;
                col = vec4f(rgb, col.a);

                if (hz > z1) {
                    c2 = c1; m2 = m1; z2 = z1;
                    c1 = col; m1 = m; z1 = hz;
                } else if (hz > z2) {
                    c2 = col; m2 = m; z2 = hz;
                }
            }
        }
    }

    var color = mix(from_color(uv), to_color(uv), w_to / max(w_from + w_to, 1e-6));
    color = vec4f(color.rgb * (1.0 - sh * clamp(max(shadow, 0.8 * hole), 0.0, 1.0)), color.a);
    color = mix(color, c2, m2);
    color = mix(color, c1, m1);
    return color;
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
