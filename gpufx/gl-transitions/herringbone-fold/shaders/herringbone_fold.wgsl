// Port of HerringboneFold.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/HerringboneFold.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const GAMMA: f32 = 1.2;
const WIDTH: f32 = 0.65;
const LIGHT: vec3f = vec3f(-0.4, 0.3, 0.866);

fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn tri(x: f32) -> f32 { return 1.0 - abs(gmod(x, 2.0) - 1.0); }

// Slope sign of tri(), softened over e around the creases.
fn slope(x: f32, e: f32) -> f32 {
    let m = gmod(x, 2.0);
    let d = min(min(m, abs(m - 1.0)), 2.0 - m);
    return select(-1.0, 1.0, m < 1.0) * smoothstep(0.0, e, d);
}

// A translational surface of two zigzags folds rigidly: every facet keeps its shape.
// x: column width, y: pleat height, z: zigzag offset, w: row height, all seen from above.
fn pleats(t: f32, b: f32, a: f32) -> vec4f {
    let v = a * cos(GAMMA) / cos(t);
    return vec4f(b * cos(t), b * sin(t), v, sqrt(max(a * a - v * v, 1e-6)));
}

// Sheet uv, signed distance to the sheet edge, column coordinate.
fn unfold(p: vec2f, g: vec4f, frame: vec2f, b: f32, c: f32, n: f32) -> vec4f {
    let y = p.y / g.w;
    let z = g.z - c * g.x / b;
    let w = (p.x + 0.5 * z - g.z * tri(y)) / g.x;
    let fp = vec2f(w * b + c * tri(y), y / n) + 0.5 * frame;
    let e = min(fp, frame - fp) * vec2f(g.x / b / sqrt(1.0 + z * z / (g.w * g.w)), g.w * n);
    return vec4f(fp / frame, min(e.x, e.y), w);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = max(params.rows, 1.0);
    let b = WIDTH / n;
    let a = 1.0 / (n * sin(GAMMA));
    let c = a * cos(GAMMA);
    let frame = vec2f(ratio, 1.0);
    let f = smoothstep(0.0, 0.7, progress);
    let d = smoothstep(0.5, 1.0, progress);
    let t = f * GAMMA * 0.985;
    let g = pleats(t, b, a);
    // The packet recedes as it falls.
    let p = (uv * frame - 0.5 * frame + vec2f(0.0, 0.75 * d * d * d)) * (1.0 + 0.6 * d);
    let m = unfold(p, g, frame, b, c, n);
    let aa = 0.0025 * (1.0 + 0.6 * d);
    // The edge bias keeps the border pixels fully covered at the start.
    let cov = clamp(0.5 + (m.z + 0.004 * (1.0 - f)) / aa, 0.0, 1.0);
    let s1 = slope(m.w, 0.003 / g.x);
    let s2 = slope(p.y / g.w, 0.003 / g.w);
    let k = g.y / g.x;
    let nrm = normalize(vec3f(-k * s1, k * s1 * g.z * s2 / g.w, 1.0));
    let lit = clamp(dot(nrm, LIGHT) / LIGHT.z, 0.0, 1.06);
    let spec = pow(max(reflect(-LIGHT, nrm).z, 0.0), 40.0) - pow(LIGHT.z, 40.0);
    let valley = 1.0 - smoothstep(0.0, 0.004 / g.x, abs(gmod(m.w + 1.0, 2.0) - 1.0));
    var sheet = from_color(clamp(m.xy, vec2f(0.0), vec2f(1.0)));
    sheet = vec4f(min(sheet.rgb * (0.3 + 0.7 * lit) * (1.0 - 0.3 * sin(t) * valley) + 0.08 * max(spec, 0.0), vec3f(1.0)), sheet.a);
    // Paper thickness: the sheet's silhouette nudged down, drawn as a darker rim.
    let r = unfold(p + vec2f(0.0, 0.005 * f), g, frame, b, c, n);
    let rim = clamp(0.5 + r.z / aa, 0.0, 1.0);
    var edge = from_color(clamp(r.xy, vec2f(0.0), vec2f(1.0)));
    edge = vec4f(edge.rgb * 0.45, edge.a);
    var next = to_color(uv);
    let soft = 0.02 + 0.06 * d;
    let sd = unfold(p - vec2f(0.02, -0.04) * (0.3 + f + 2.0 * d), g, frame, b, c, n).z;
    next = vec4f(next.rgb * (1.0 - params.shadow * (1.0 - 0.5 * d) * smoothstep(-soft, soft, sd) * smoothstep(0.0, 0.15, f)), next.a);
    return mix(mix(next, edge, rim), sheet, cov);
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
