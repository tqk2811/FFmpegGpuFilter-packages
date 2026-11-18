// Port of Accordion.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Accordion.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const LIGHT_SIDE: f32 = 0.55;
const LIGHT_FRONT: f32 = 0.835;
const EDGE: f32 = 0.0015;

fn gmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

// Brightness of a panel folded by angle (c, s) = (cos, sin), facing the light (1) or away (-1).
fn panel_light(c: f32, s: f32, facing: f32) -> f32 {
    let lambert = (c * LIGHT_FRONT + facing * s * LIGHT_SIDE) / LIGHT_FRONT;
    return mix(1.0, clamp(lambert, 0.08, 1.25), params.shading);
}

// f: position along the clip (0 at its anchored side), c: cos of the fold angle, len: its
// length, b: position across it (frame heights).
fn pleated(f: f32, c: f32, len: f32, b: f32, b_len: f32, incoming: bool, flip_a: bool, vertical: bool) -> vec4f {
    let m = 2.0 * f32(max(params.pleats, 1));
    let s = sqrt(max(1.0 - c * c, 0.0));
    let u = f * m;
    // f = 1 is the end of the last panel, not the start of one more.
    let panel = min(floor(u), m - 1.0);
    let fu = u - panel;
    // The ridges (odd boundaries) stay in the frame plane, the valleys (even ones) recede.
    let tri = 1.0 - abs(gmod(u, 2.0) - 1.0);
    let panel_len = len / m;
    let z = panel_len * s * (1.0 - tri);
    let scale = 1.0 / (1.0 + params.perspective * z);
    let bb = (b - 0.5 * b_len) / scale / b_len + 0.5;
    // Soft top and bottom edges while folded (sharp when flat).
    let edge = EDGE * min(1.0, 20.0 * s * c) + 1e-6;
    let cover = clamp(min(bb, 1.0 - bb) * b_len * scale / edge, 0.0, 1.0);
    let a = select(f, 1.0 - f, flip_a);
    let st = clamp(select(vec2f(a, bb), vec2f(bb, a), vertical), vec2f(0.0), vec2f(1.0));
    let img = select(from_color(st), to_color(st), incoming);
    let facing = select(-1.0, 1.0, gmod(panel, 2.0) < 0.5);
    let to_edge = min(fu, 1.0 - fu) * panel_len * c;
    let k = 0.5 + 0.5 * clamp(to_edge / EDGE, 0.0, 1.0);
    var light = mix(panel_light(c, s, -facing), panel_light(c, s, facing), k);
    let valley = 1.0 - tri;
    light *= 1.0 - 0.4 * params.shading * s * valley * valley;
    return mix(params.back_color, vec4f(img.rgb * light, img.a), cover);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let dir = params.direction;
    let vertical = abs(dir.y) > abs(dir.x);
    let positive = select(dir.x > 0.0, dir.y > 0.0, vertical);
    // a: along the motion, 0 on the side the first clip folds up toward; b: across it.
    var a = select(uv.x, uv.y, vertical);
    if (positive) { a = 1.0 - a; }
    let b = select(uv.y, uv.x, vertical);
    let len = select(ratio, 1.0, vertical);
    let b_len = select(1.0, ratio, vertical);
    let p = progress;
    let e = mix(p, p * p * (3.0 - 2.0 * p), 0.8);
    let c_from = 1.0 - e;
    let c_to = e;
    if (a < c_from || c_to <= 0.0) {
        return pleated(a / c_from, c_from, len, b * b_len, b_len, false, positive, vertical);
    }
    return pleated(1.0 - (1.0 - a) / c_to, c_to, len, b * b_len, b_len, true, positive, vertical);
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
