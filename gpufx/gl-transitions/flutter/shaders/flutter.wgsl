// Port of Flutter.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Flutter.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EYE: vec3f = vec3f(0.0, 0.0, -2.0);
const TILT: f32 = 1.05;
const BANK: f32 = 0.35;
const YAW: f32 = 0.45;
const BEND: f32 = 0.07;
const DEPTH: f32 = 0.65;

fn rot_x(a: f32) -> mat3x3f { let c = cos(a); let s = sin(a); return mat3x3f(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c); }
fn rot_y(a: f32) -> mat3x3f { let c = cos(a); let s = sin(a); return mat3x3f(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }

fn pose(env: f32, side: f32, vel: f32) -> mat3x3f {
    return rot_y(YAW * vel) * rot_x(TILT * env) * rot_y(BANK * side);
}

// Offset of the bent sheet toward the viewer at x, and its slope.
fn curl(x: f32, env: f32, ratio: f32) -> vec2f {
    let w = 0.5 * ratio;
    let u = clamp(x / w, -1.0, 1.0);
    let a = BEND * env * min(ratio, 1.0);
    return vec2f(a * (u * u - 1.0 / 3.0), 2.0 * a * u / w);
}

// Sheet coordinates where the ray o + k d meets the bent sheet, and k.
fn on_sheet(o: vec3f, d: vec3f, c: vec3f, r: mat3x3f, env: f32, ratio: f32) -> vec3f {
    let n = r[2];
    var dn = dot(d, n);
    if (abs(dn) < 1e-4) { dn = 1e-4; }
    var q = vec3f(0.0);
    for (var i = 0; i < 3; i++) {
        let k = dot(c - n * curl(q.x, env, ratio).x - o, n) / dn;
        let h = o + k * d - c;
        q = vec3f(dot(h, r[0]), dot(h, r[1]), k);
    }
    return q;
}

fn sheet_mask(q: vec3f, aa: vec2f, ratio: f32) -> f32 {
    let e = abs(q.xy) - vec2f(0.5 * ratio, 0.5);
    return (1.0 - smoothstep(-aa.x, aa.x, e.x)) * (1.0 - smoothstep(-aa.y, aa.y, e.y)) * step(0.0, q.z);
}

fn sheet_color(q: vec3f, ratio: f32) -> vec4f {
    return from_color(clamp(vec2f(q.x / ratio, q.y) + 0.5, vec2f(0.0), vec2f(1.0)));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let swings = params.swings;
    let sway = params.sway;
    let shading = params.shading;
    let t = progress;
    let env = smoothstep(0.0, 0.4, t);
    let ph = 2.0 * PI * swings * t;
    let side = sin(ph) * env;
    let vel = cos(ph) * env;
    // The glide follows a pendulum arc, rising at the end of each swing.
    let lift = 0.35 * sway;
    let focal = -EYE.z;
    // Fall far enough that every corner of the end pose leaves the frame.
    let r1 = pose(1.0, sin(2.0 * PI * swings), cos(2.0 * PI * swings));
    var drop = 0.0;
    for (var i = 0; i < 4; i++) {
        let c = vec2f(select(0.5 * ratio, -0.5 * ratio, i < 2), f32(i % 2) - 0.5);
        let o = r1 * vec3f(c, 0.0) - r1[2] * BEND * min(ratio, 1.0);
        drop = max(drop, 0.51 * (focal + DEPTH + o.z) / focal + o.y);
    }
    drop += lift;
    let cc = vec3f(sway * side, -drop * t * t * (0.3 + 0.7 * t) + lift * side * side, DEPTH * (0.45 * env + 0.55 * t * t));
    let r = pose(env, side, vel);
    let p = vec2f((uv.x - 0.5) * ratio, uv.y - 0.5);
    let d = vec3f(p, focal);
    let q = on_sheet(EYE, d, cc, r, env, ratio);
    // Edge width in sheet units, wider across the tilt that foreshortens it.
    let aa = (0.0001 + 0.0025 * env * (1.0 + cc.z / focal)) * vec2f(1.0, 1.0 / cos(TILT * env));
    let m = sheet_mask(q, aa, ratio);
    let gap = 1.0 - 0.7 * t;
    let qs = on_sheet(EYE, vec3f(p - vec2f(0.07, -0.14) * gap * env, focal), cc, r, env, ratio);
    let sh = sheet_mask(qs, vec2f(0.01 + 0.1 * gap), ratio) * sheet_color(qs, ratio).a * env;
    var bg = to_color(uv);
    bg = vec4f(bg.rgb * (1.0 - 0.75 * shading * sh), bg.a);
    var img = sheet_color(q, ratio);
    let nn = normalize(r * vec3f(-curl(q.x, env, ratio).y, 0.0, -1.0));
    let k = normalize(vec3f(-0.4, 0.3, -1.0));
    let lit = min(max(dot(nn, k), 0.0) / -k.z, 1.0);
    let spec = pow(max(dot(nn, normalize(k + normalize(-d))), 0.0), 30.0);
    img = vec4f(min(img.rgb * mix(1.0, lit, shading * env) + 0.3 * shading * env * spec, vec3f(1.0)), img.a);
    return mix(bg, img, m);
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
