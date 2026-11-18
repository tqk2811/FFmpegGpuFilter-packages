// Port of Vortex.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Vortex.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The squares leave in GROUPS waves, each one flying for DURATION of the transition.
const GROUPS: i32 = 24;
const DURATION: f32 = 0.25;
const AA: f32 = 0.0015;
const TAU: f32 = 6.2831853;

fn hash(n: vec2f) -> f32 {
    return fract(sin(dot(n, vec2f(12.9898, 78.233))) * 43758.5453);
}

fn group_of(n: vec2f, h: f32, c: vec2f, max_r: f32) -> i32 {
    let r = min(length((n + 0.5) * h - c) / (0.85 * max_r), 1.0);
    let key = clamp(mix(r * sqrt(r), hash(n), clamp(params.randomness, 0.0, 1.0)), 0.0, 0.9999);
    return i32(floor(key * f32(GROUPS)));
}

// Local time of a wave's flight, 0 before it leaves, 1 once it has vanished.
fn flight(g: i32, progress: f32) -> f32 {
    let delay = f32(g) / f32(GROUPS) * (1.0 - DURATION);
    return clamp((progress - delay) / DURATION, 0.0, 1.0);
}

fn premul(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let aspect = vec2f(ratio, 1.0);
    let p = uv * aspect;
    // `center` is given y down.
    let c = vec2f(params.center.x, 1.0 - params.center.y) * aspect;
    let max_r = max(max(length(c), length(c - vec2f(ratio, 0.0))), max(length(c - vec2f(0.0, 1.0)), length(c - aspect)));
    let h = 1.0 / f32(max(params.grid, 1));
    let reach = 0.7 * max_r;
    let n0 = floor(p / h);
    // It shows once the square above it has started to move away.
    let k0 = smoothstep(0.0, 0.05, flight(group_of(n0, h, c, max_r), progress));
    var col = mix(premul(from_color(uv)), premul(to_color(uv)), k0);
    // The flying squares, painted from the last wave to leave to the first.
    for (var k = 0; k < GROUPS; k++) {
        let g = GROUPS - 1 - k;
        let s = flight(g, progress);
        if (s <= 0.0 || s >= 1.0) { continue; }
        let e = s * s;
        // As in a tornado, the squares near the eye spin much faster than the outer ones.
        let angle = params.spin * TAU * e * 2.0 / (1.0 + 6.0 * f32(g) / f32(GROUPS));
        let push = reach * e * s;
        let size = (1.0 + 0.35 * sin(3.1415927 * s)) * (1.0 - s * s * s);
        let ca = cos(angle);
        let sa = sin(angle);
        let rot = mat2x2f(ca, sa, -sa, ca);
        // Undo the wave's spiral to guess which square lands here, then test its neighbors.
        let u = (p - c) * rot;
        let ru = length(u);
        let guess = c + select(vec2f(0.0), u / ru, ru > 0.0) * max(ru - push, 0.0);
        let ng = floor(guess / h);
        for (var j = -1; j <= 1; j++) {
            for (var i = -1; i <= 1; i++) {
                let n = ng + vec2f(f32(i), f32(j));
                if (group_of(n, h, c, max_r) != g) { continue; }
                let home = (n + 0.5) * h;
                let rel = home - c;
                let rr = length(rel);
                let dir = select(vec2f(0.0), rel / rr, rr > 0.0);
                let pos = c + rot * (dir * (rr + push));
                let tumble = angle + (hash(n + 17.0) - 0.5) * 3.0 * e * sign(params.spin);
                let ct = cos(tumble);
                let st = sin(tumble);
                let d = ((p - pos) * mat2x2f(ct, st, -st, ct)) / max(size, 1e-4);
                let edge = 0.5 * h - max(abs(d.x), abs(d.y));
                let cov = clamp(edge * size / (2.0 * AA) + 0.5, 0.0, 1.0);
                let src = home + d;
                if (cov <= 0.0 || src.x < 0.0 || src.y < 0.0 || src.x > ratio || src.y > 1.0) { continue; }
                let piece = premul(from_color(src / aspect)) * cov;
                col = piece + col * (1.0 - piece.a);
            }
        }
    }
    if (col.a > 0.0) { return vec4f(col.rgb / col.a, col.a); }
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
