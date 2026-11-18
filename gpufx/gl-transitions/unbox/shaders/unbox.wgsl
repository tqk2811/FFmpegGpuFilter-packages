// Port of Unbox.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Unbox.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0016;
const YAW0: f32 = 0.45;
const LIGHT: vec3f = vec3f(-0.35045, 0.45058, 0.82107);

fn wall_angle(u: f32) -> f32 {
    let k = u / 0.72;
    return select(0.12 * sin(PI * (u - 0.72) / 0.28), 0.5 * PI * (1.0 - k * k), u < 0.72);
}

// Sides of quad i: floor (0), bottom and top walls (1, 2), left and right walls (3, 4), corner tabs (5 to 8).
fn side_sign(i: i32) -> vec2f {
    if (i == 0) { return vec2f(-1.0); }
    if (i == 1) { return vec2f(0.0, -1.0); }
    if (i == 2) { return vec2f(0.0, 1.0); }
    if (i == 3) { return vec2f(-1.0, 0.0); }
    if (i == 4) { return vec2f(1.0, 0.0); }
    return vec2f(select(1.0, -1.0, i == 5 || i == 7), select(1.0, -1.0, i < 7));
}

// Hinge corner of quad i on the flat sheet.
fn quad_origin(i: i32, w: f32, c: f32) -> vec2f {
    let sg = side_sign(i);
    return vec2f(select(c, w - c, sg.x > 0.0), select(c, 1.0 - c, sg.y > 0.0));
}

// Picture directions of the quad edges (u, v).
fn quad_axes(i: i32) -> vec4f {
    let sg = side_sign(i);
    if (i <= 2) { return vec4f(1.0, 0.0, 0.0, select(sg.y, 1.0, i == 0)); }
    if (i <= 4) { return vec4f(0.0, 1.0, sg.x, 0.0); }
    return vec4f(sg.x, 0.0, 0.0, sg.y);
}

fn quad_size(i: i32, w: f32, c: f32) -> vec2f {
    if (i == 0) { return vec2f(w - 2.0 * c, 1.0 - 2.0 * c); }
    if (i <= 2) { return vec2f(w - 2.0 * c, c); }
    if (i <= 4) { return vec2f(1.0 - 2.0 * c, c); }
    return vec2f(c);
}

// Edges that are free cuts (s = 0, s = len.x, t = 0, t = len.y); the others are hinges or folds.
fn quad_cut(i: i32) -> vec4f {
    if (i == 0) { return vec4f(0.0); }
    if (i <= 2) { return vec4f(0.0, 0.0, 0.0, 1.0); }
    if (i <= 4) { return vec4f(1.0, 1.0, 0.0, 1.0); }
    return vec4f(0.0, 1.0, 1.0, 1.0);
}

// Edge directions U, V of quad i in box space (columns 0, 1) and its origin (column 2); wt holds
// cos and sin of the bottom/top and side wall angles, tt those of the tabs.
fn quad_frame(i: i32, w: f32, c: f32, wt: vec4f, tt: vec2f) -> mat3x3f {
    let sg = side_sign(i);
    let o = vec3f(quad_origin(i, w, c), 0.0);
    var u = vec3f(1.0, 0.0, 0.0);
    var v = vec3f(0.0, 1.0, 0.0);
    if (i == 1 || i == 2) {
        v = vec3f(0.0, sg.y * wt.x, wt.y);
    } else if (i == 3 || i == 4) {
        u = vec3f(0.0, 1.0, 0.0);
        v = vec3f(sg.x * wt.z, 0.0, wt.w);
    } else if (i >= 5) {
        // The tabs hang on the bottom and top walls and fold against the outside of the side walls.
        v = vec3f(0.0, sg.y * wt.x, wt.y);
        u = vec3f(sg.x * tt.x, 0.0, 0.0) + tt.y * vec3f(0.0, -sg.y * wt.y, wt.x);
    }
    return mat3x3f(u, v, o);
}

fn rotate(v: vec3f, rot: vec2f) -> vec3f {
    return vec3f(v.x * rot.x - v.y * rot.y, v.x * rot.y + v.y * rot.x, v.z);
}

// Color of quad i at the hit (s, t, coverage, ray dot normal).
fn shade_face(i: i32, hit: vec4f, w: f32, c: f32, wt: vec4f, tt: vec2f, rot: vec2f, amount: f32) -> vec4f {
    if (i < 0) { return vec4f(0.0); }
    let paper = params.paper;
    let f = quad_frame(i, w, c, wt, tt);
    let ax = quad_axes(i);
    let len = quad_size(i, w, c);
    let st = hit.xy;
    let det = ax.x * ax.w - ax.y * ax.z;
    let is_front = hit.w * det < 0.0;
    let n = rotate(cross(f[0], f[1]), rot) * select(-1.0, 1.0, is_front) * det;
    var col = to_color(clamp((quad_origin(i, w, c) + st.x * ax.xy + st.y * ax.zw) / vec2f(w, 1.0), vec2f(0.0), vec2f(1.0)));
    var lit = min((0.45 + 0.55 * max(dot(n, LIGHT), 0.0)) / (0.45 + 0.55 * LIGHT.z), 1.0);
    let up = select(clamp(f[1].z, 0.0, 1.0), 0.0, i == 0);
    if (is_front) {
        // The picture side of a raised wall faces into the box: darker toward the crease with the floor.
        lit *= 1.0 - up * (0.35 + 0.4 * (1.0 - st.y / len.y));
        if (i == 0) {
            let ao = exp(-vec4f(st.x, len.x - st.x, st.y, len.y - st.y) / (0.25 * c)) * wt.wwyy;
            lit *= 1.0 - 0.45 * max(max(ao.x, ao.y), max(ao.z, ao.w));
        }
        col = vec4f(mix(col.rgb, paper.rgb * 0.8, 0.25 * up), col.a);
    } else {
        col = vec4f(paper.rgb, paper.a * col.a);
    }
    // A lit band along the free top edge of a raised wall reads as the card thickness.
    let rim = up * quad_cut(i).w * (1.0 - smoothstep(0.006, 0.014, len.y - st.y));
    return vec4f(mix(col.rgb * mix(1.0, lit, params.shading * amount), paper.rgb * 1.05, rim * amount), col.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let w = globals.size.x / globals.size.y;
    let c = clamp(params.depth, 0.1, 0.35) * min(w, 1.0);
    let dd = 1.0 / (0.25 + 0.75 * clamp(params.perspective, 0.0, 1.0));
    let f = clamp(progress / 0.36, 0.0, 1.0);
    let fe = 1.0 - (1.0 - f) * (1.0 - f);
    let h = 0.22 * (1.0 - f * f) + 0.03 * sin(PI * clamp((progress - 0.36) / 0.09, 0.0, 1.0));
    // Starts just clear of the frame with its initial yaw, whatever the ratio.
    let y0 = 0.52 + 0.5 * w * sin(YAW0) + 0.5 * cos(YAW0);
    let off = vec3f(0.0, y0 * (1.0 - fe), h);
    let yaw = YAW0 * (1.0 - fe) * (1.0 - fe);
    let rot = vec2f(cos(yaw), sin(yaw));
    let tb = wall_angle(clamp((progress - 0.42) / 0.34, 0.0, 1.0));
    let ts = wall_angle(clamp((progress - 0.6) / 0.4, 0.0, 1.0));
    let wt = vec4f(cos(tb), sin(tb), cos(ts), sin(ts));
    let tt = vec2f(cos(0.97 * tb), sin(0.97 * tb));
    let amount = clamp(10.0 * (tb + ts + h), 0.0, 1.0);
    let aa = EDGE * amount + 1e-4;
    let cc = vec3f(0.5 * w, 0.5, 0.0);
    let eye = vec3f(0.5 * w, 0.5, dd);
    let dir = vec3f(uv.x * w, uv.y, 0.0) - eye;
    // The two nearest faces along the ray; the front one is composited over the back one.
    var t1 = 1e4;
    var t2 = 1e4;
    var h1 = vec4f(0.0);
    var h2 = vec4f(0.0);
    var i1 = -1;
    var i2 = -1;
    for (var i = 0; i < 9; i++) {
        let fr = quad_frame(i, w, c, wt, tt);
        let u = rotate(fr[0], rot);
        let v = rotate(fr[1], rot);
        let n = cross(u, v);
        let den = dot(dir, n);
        if (abs(den) < 1e-6) { continue; }
        let o = cc + rotate(fr[2] - cc, rot) + off;
        let t = dot(o - eye, n) / den;
        if (t <= 0.0 || t >= t2) { continue; }
        let q = eye + t * dir - o;
        let st = vec2f(dot(q, u), dot(q, v));
        let len = quad_size(i, w, c);
        let cut = quad_cut(i);
        // Hinges overlap slightly and cut edges antialias outward, so flat seams never crack.
        let d = mix(vec4f(st.x, len.x - st.x, st.y, len.y - st.y) + 1e-4, vec4f(st.x, len.x - st.x, st.y, len.y - st.y), cut);
        if (min(min(d.x, d.y), min(d.z, d.w)) <= -aa) { continue; }
        let e = mix(vec4f(1.0), clamp(d / aa + 1.0, vec4f(0.0), vec4f(1.0)), cut);
        let hit = vec4f(st, e.x * e.y * e.z * e.w, den);
        if (t < t1) { t2 = t1; h2 = h1; i2 = i1; t1 = t; h1 = hit; i1 = i; }
        else { t2 = t; h2 = hit; i2 = i; }
    }
    var c1 = shade_face(i1, h1, w, c, wt, tt, rot, amount);
    var c2 = shade_face(i2, h2, w, c, wt, tt, rot, amount);
    let p1 = eye + t1 * dir;
    let p2 = eye + t2 * dir;
    var ground = from_color(uv);
    let gp = eye + dir;
    var sh_g = 0.0;
    var sh1 = 0.0;
    var sh2 = 0.0;
    for (var i = 0; i < 9; i++) {
        let fr = quad_frame(i, w, c, wt, tt);
        let u = rotate(fr[0], rot);
        let v = rotate(fr[1], rot);
        let o = cc + rotate(fr[2] - cc, rot) + off;
        let len = quad_size(i, w, c);
        let n = cross(u, v);
        let den = dot(LIGHT, n);
        if (abs(den) < 1e-6) { continue; }
        for (var k = 0; k < 3; k++) {
            if ((k == 1 && i1 < 0) || (k == 2 && i2 < 0)) { continue; }
            var p = gp;
            if (k == 1) { p = p1; } else if (k == 2) { p = p2; }
            let s = dot(o - p, n) / den;
            if (s < 2e-3) { continue; }
            let q = p + s * LIGHT - o;
            let st = vec2f(dot(q, u), dot(q, v));
            let soft = 0.004 + 0.12 * s;
            let ins = min(min(st.x, len.x - st.x), min(st.y, len.y - st.y));
            let a = smoothstep(-soft, soft, ins) / (1.0 + 1.5 * s);
            if (k == 0) { sh_g = max(sh_g, a); } else if (k == 1) { sh1 = max(sh1, a); } else { sh2 = max(sh2, a); }
        }
    }
    let sk = 0.9 * params.shading * amount * min(8.0 * progress, 1.0);
    ground = vec4f(ground.rgb * (1.0 - sk * sh_g), ground.a);
    c1 = vec4f(c1.rgb * (1.0 - sk * sh1), c1.a);
    c2 = vec4f(c2.rgb * (1.0 - sk * sh2), c2.a);
    return mix(mix(ground, c2, h2.z), c1, h1.z);
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
