// Port of CoinSettle.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CoinSettle.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
// Far camera and a smaller standing card keep the raised edge from looming over the frame.
const D: f32 = 6.0;
const START_SCALE: f32 = 0.72;
const AA: f32 = 0.0015;
// Whirl rate grows like 1/sqrt(s + K), capped so the last frames do not strobe.
const K: f32 = 0.04;

fn rot_axis(v: vec3f, a: vec3f, t: f32) -> vec3f {
    return v * cos(t) + cross(a, v) * sin(t) + a * dot(a, v) * (1.0 - cos(t));
}

fn non_zero(x: f32) -> f32 {
    return select(max(x, 1e-5), min(x, -1e-5), x < 0.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let s = 1.0 - progress;
    let tilt = 0.5 * PI * pow(s, 1.2);
    let phi = 2.0 * PI * params.whirls * (sqrt(1.0 + K) - sqrt(s + K)) / (sqrt(1.0 + K) - sqrt(K)) - 0.4;
    let psi = params.twist * s * s;

    let axis = vec3f(-sin(phi), cos(phi), 0.0);
    let e1 = rot_axis(vec3f(cos(psi), sin(psi), 0.0), axis, tilt);
    let e2 = rot_axis(vec3f(-sin(psi), cos(psi), 0.0), axis, tilt);
    let n = cross(e1, e2);
    let sc = mix(1.0, START_SCALE, 1.0 - cos(tilt));
    let hs = vec2f(0.5 * ratio, 0.5) * sc;
    // The lowest corner touches the table, so the center rides up and down as it rocks over the corners.
    let h = abs(hs.x * e1.z) + abs(hs.y * e2.z);
    let cc = vec3f(0.0, 0.0, -h);

    let p = vec2f((uv.x - 0.5) * ratio, uv.y - 0.5);
    let d = vec3f(p, D);
    let dn = non_zero(dot(d, n));
    let t = (D - h) * n.z / dn;
    let g = vec3f(0.0, 0.0, -D) + d * t - cc;
    let q = vec2f(dot(g, e1), dot(g, e2));
    let eq = abs(q) - hs;
    // Edge distance in screen units through the projection's analytic Jacobian, crisp even edge-on.
    let g1 = t * (e1.xy - dot(d, e1) / dn * n.xy);
    let g2 = t * (e2.xy - dot(d, e2) / dn * n.xy);
    let ex = eq / clamp(vec2f(length(g1), length(g2)), vec2f(1e-3), vec2f(40.0));
    var m = 1.0 - smoothstep(0.0, AA, max(ex.x, ex.y));
    m *= smoothstep(0.001, 0.02, abs(n.z));

    let ld = normalize(vec3f(-0.4, 0.5, -1.0));
    let pp = vec3f(p, 0.0);
    let ln = dot(ld, n);
    let ts = dot(cc - pp, n) / non_zero(ln);
    let gs = pp + ld * ts - cc;
    let es = abs(vec2f(dot(gs, e1), dot(gs, e2))) - hs;
    let soft = 0.01 + 0.15 * clamp(ts, 0.0, 2.0);
    var shadow = (1.0 - smoothstep(-soft, soft, max(es.x, es.y))) * smoothstep(0.0, 0.15, h) * smoothstep(0.0, 0.06, progress) * smoothstep(0.0, 0.02, ts);
    // A card edge-on to the light casts a hairline that would alias.
    shadow *= smoothstep(0.03, 0.15, abs(ln));

    let bg0 = from_color(uv);
    let bg = vec4f(bg0.rgb * (1.0 - 0.6 * shading * shadow), bg0.a);

    let img = to_color(clamp(vec2f(q.x / ratio, q.y) / sc + 0.5, vec2f(0.0), vec2f(1.0)));
    let lit = ld.z - dot(n, ld);
    let spec = pow(max(-dot(n, normalize(ld + vec3f(0.0, 0.0, -1.0))), 0.0), 30.0) * sin(tilt);
    let rim = 1.0 - smoothstep(vec2f(0.0), vec2f(0.025 * hs.y), -eq);
    let rgb = img.rgb * (1.0 + shading * max(1.2 * lit, -0.45)) + shading * (0.3 * spec + 0.25 * sin(tilt) * max(rim.x, rim.y));
    return mix(bg, vec4f(rgb, img.a), m);
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
