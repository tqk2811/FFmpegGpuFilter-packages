// Port of Sphere.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Sphere.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;
const AA: f32 = 0.0015;
const LIGHT: vec3f = vec3f(-0.5, 0.6, 1.0) / 1.2689;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let b = to_color(uv);
    let dir = select(vec2f(1.0, 0.0), normalize(params.direction), length(params.direction) > 0.0);
    let side = vec2f(-dir.y, dir.x);
    let p = (uv - 0.5) * vec2f(ratio, 1.0);
    let shorter = min(ratio, 1.0);
    let r0 = clamp(params.size, 0.1, 0.5) * shorter;
    // The picture curves into a ball (flat at the start), then the ball shrinks while rolling
    // away until it and its shadow have left the frame.
    var w = clamp(progress / 0.45, 0.0, 1.0);
    w = 1.0 - (1.0 - w) * (1.0 - w);
    var away = smoothstep(0.3, 1.0, progress);
    away *= away;
    let wrapped = r0 / max(w, 1e-4);
    let radius = wrapped * mix(1.0, 0.5, away);
    // The picture is pulled tighter as it wraps, so it ends up covering the whole ball.
    let tight = mix(1.0, min(1.0, 0.48 * shorter / (PI * r0)), w * w);
    let paper = radius * tight;
    let e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
    let full = e + 1.1 * r0 + 2.0 * AA;
    let center = dir * away * full;
    // Rolling without slipping while the radius shrinks.
    let angle = -2.0 * full * log(1.0 - 0.5 * away) / wrapped;
    let d = p - center;
    let r = length(d);
    let sd = d - vec2f(0.25, -0.3) * radius * w;
    let sh = params.shadow * w * (1.0 - smoothstep(0.6 * radius, 1.4 * radius, length(sd)));
    let bg = vec4f(b.rgb * b.a * (1.0 - sh), b.a);
    var ball = vec4f(0.0);
    let cover = 1.0 - smoothstep(radius - AA, radius + AA, r);
    if (cover > 0.0) {
        let nd = d / radius;
        let n = vec3f(nd, sqrt(max(1.0 - dot(nd, nd), 0.0)));
        let u = dot(n.xy, dir);
        let s = dot(n.xy, side);
        let cu = cos(angle);
        let su = sin(angle);
        let q = vec3f(u * cu - n.z * su, s, u * su + n.z * cu);
        // Wrapped around the ball from its front point, distances kept along the surface.
        let lq = length(q.xy);
        let arc = atan2(lq, q.z) * paper;
        let img = select(vec2f(0.0), (q.x * dir + q.y * side) / lq * arc, lq > 0.0);
        let iuv = img / vec2f(ratio, 1.0) + 0.5;
        let edge = min(iuv, 1.0 - iuv) * vec2f(ratio, 1.0);
        let inside = cover * smoothstep(-AA, AA, min(edge.x, edge.y));
        if (inside > 0.0) {
            let c = from_color(clamp(iuv, vec2f(0.0), vec2f(1.0)));
            let diff = max(dot(n, LIGHT), 0.0);
            let spec = pow(max(reflect(-LIGHT, n).z, 0.0), 24.0);
            let k = params.shading * w;
            let lit = c.rgb * mix(1.0, 0.25 + 0.85 * diff, k) + 0.35 * k * spec;
            ball = vec4f(clamp(lit, vec3f(0.0), vec3f(1.0)) * c.a, c.a) * inside;
        }
    }
    // Premultiplied, so transparent clips do not bleed their color.
    let c = ball + bg * (1.0 - ball.a);
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
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
