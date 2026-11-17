// Port of PaperFold.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PaperFold.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0015;
const SHOW: f32 = 0.1;
const CREASE: f32 = 0.02;
const LIGHT: vec3f = vec3f(-0.3995, 0.4494, 0.799);

fn ratio() -> f32 { return globals.size.x / globals.size.y; }

fn front(st: vec2f) -> vec4f { return from_color(st / vec2f(ratio(), 1.0)); }

fn back(st: vec2f) -> vec4f {
    let c = front(st);
    return vec4f(mix(params.paper.rgb, c.rgb, SHOW), c.a * params.paper.a);
}

// The face of the packet top layer: the picture itself during the first fold, then the back
// of the right half, laid mirrored over the left half.
fn top_face(st: vec2f, second: bool) -> vec4f {
    if (second) { return back(vec2f(ratio() - st.x, st.y)); }
    return front(st);
}

// Distance inside the rectangle [0, h] x [0, k] (negative outside).
fn inside(p: vec2f, h: f32, k: f32) -> f32 { return min(min(p.x, h - p.x), min(p.y, k - p.y)); }

// Where the ray o + t * v meets the flap plane: (t, distance from the hinge, y), t < 0 if never.
fn hit_flap(o: vec3f, v: vec3f, h: f32, n: vec3f, along: vec3f) -> vec3f {
    let den = dot(n, v);
    if (abs(den) < 1e-5) { return vec3f(-1.0, 0.0, 0.0); }
    let hinge = vec3f(h, 0.0, 0.0);
    let t = dot(n, hinge - o) / den;
    let q = o + t * v;
    return vec3f(t, dot(q - hinge, along), q.y);
}

// How much the point q is shaded, lit by l: by the flap, and by the flat part once it lifts.
fn shadow_at(q: vec3f, l: vec3f, h: f32, k: f32, n: vec3f, along: vec3f) -> f32 {
    var sh = 0.0;
    if (q.z < -1e-4) {
        let soft = 0.004 - 0.4 * q.z;
        sh = smoothstep(-soft, soft, inside(q.xy - q.z / l.z * l.xy, h, k));
    }
    let hit = hit_flap(q, l, h, n, along);
    if (hit.x > 0.0) {
        let height = hit.x * l.z;
        let soft = 0.004 + 0.3 * height;
        sh = max(sh, min(4.0 * n.x * n.x, 1.0) * smoothstep(-soft, soft, inside(hit.yz, h, k)) / (1.0 + 3.0 * height));
    }
    return sh;
}

// A frame vector into the sheet frame, turned by yaw, pitch and spin, each as (cos, sin).
fn to_sheet(v_in: vec3f, yaw: vec2f, pitch: vec2f, spin: vec2f) -> vec3f {
    var v = vec3f(yaw.x * v_in.x + yaw.y * v_in.z, v_in.y, yaw.x * v_in.z - yaw.y * v_in.x);
    v = vec3f(v.x, pitch.x * v.y + pitch.y * v.z, pitch.x * v.z - pitch.y * v.y);
    return vec3f(spin.x * v.x + spin.y * v.y, spin.x * v.y - spin.y * v.x, v.z);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let w = ratio();
    let shade = clamp(params.shading, 0.0, 1.0);
    let s = 2.0 * smoothstep(0.0, 0.62, progress);
    let second = s > 1.0;
    let x = select(s, s - 1.0, second);
    let a = PI * mix(x, x * x * (3.0 - 2.0 * x), 0.6);
    let f = clamp((progress - 0.5) / 0.47, 0.0, 1.0);
    let turn = clamp(params.tilt, 0.0, 1.0) * (smoothstep(0.0, 0.25, progress) - smoothstep(0.4, 0.8, progress));
    let yaw = vec2f(cos(0.45 * turn), sin(0.45 * turn));
    let pitch = vec2f(cos(0.55 * turn), -sin(0.55 * turn));
    let dist = 2.5 * max(w, 1.0);
    let recede = dist * 0.35 * turn;
    let dir = select(vec2f(1.0, 0.0), normalize(params.direction), length(params.direction) > 0.0);
    // The point held in the middle of the frame slides to the middle of the packet.
    let c = vec2f(0.5 * w - 0.25 * w * min(s, 1.0), 0.5 - 0.25 * max(s - 1.0, 0.0));
    let reach = 0.5 * (abs(dir.x) * w + abs(dir.y)) + length(vec2f(0.25 * w, 0.25)) + 0.4;
    let lift = 0.3 * smoothstep(0.0, 0.5, f);
    let turned = select(-0.7, 0.7, dir.x < 0.0) * f * f;
    let spin = vec2f(cos(turned), sin(turned));
    // Eye, ray and light in the sheet frame, where the sheet lies on z = 0 and the second clip on z = -lift.
    let center = vec3f(vec2f(0.5 * w, 0.5) + dir * reach * f * f, -recede);
    let eye = vec3f(0.5 * w, 0.5, dist);
    var e = to_sheet(eye - center, yaw, pitch, spin) + vec3f(c, 0.0);
    var d = to_sheet(vec3f(uv.x * w, uv.y, 0.0) - eye, yaw, pitch, spin);
    var l = to_sheet(LIGHT, yaw, pitch, spin);
    if (second) {
        e = vec3f(e.yx, e.z);
        d = vec3f(d.yx, d.z);
        l = vec3f(l.yx, l.z);
    }
    let h = select(0.5 * w, 0.5, second);
    let k = select(1.0, 0.5 * w, second);
    let creased = sin(a);
    let n = vec3f(-creased, 0.0, cos(a));
    let along = vec3f(cos(a), 0.0, creased);
    var col = to_color(uv);
    if (d.z < 0.0) {
        let g = e + d * (e.z + lift) / -d.z;
        col = vec4f(col.rgb * (1.0 - 0.7 * shade * (1.0 - f * f) * shadow_at(g, l, h, k, n, along)), col.a);
    }
    let t = select(-1.0, e.z / -d.z, d.z < 0.0);
    let p = e + t * d;
    let m = clamp(inside(p.xy, h, k) / (EDGE * t) + 1.0, 0.0, 1.0);
    if (t > 0.0 && m > 0.0) {
        var img = top_face(select(p.xy, p.yx, second), second);
        let sh = shadow_at(p, l, h, k, n, along);
        img = vec4f(img.rgb * (1.0 - 0.7 * shade * sh) * (1.0 - 0.5 * shade * creased * exp(-abs(h - p.x) / CREASE)), img.a);
        col = mix(col, img, m);
    }
    let hit = hit_flap(e, d, h, n, along);
    if (hit.x > 0.0) {
        let r = hit.y;
        // Edges seen at a grazing angle are narrower on screen.
        let dr = dot(along, normalize(d));
        let fore = sqrt(max(1.0 - dr * dr, 0.0025));
        let mf = clamp(min(min(r, h - r) * fore, min(hit.z, k - hit.z)) / (EDGE * hit.x) + 1.0, 0.0, 1.0);
        if (mf > 0.0) {
            let up = dot(n, e - vec3f(h, 0.0, 0.0)) > 0.0;
            var st = vec2f(h + r, hit.z);
            if (second) { st = st.yx; }
            var img = back(st);
            if (up) { img = top_face(st, second); }
            // Lit by the light, relative to the sheet lying flat.
            let lit = dot(select(-n, n, up), l) - l.z;
            img = vec4f(img.rgb * max(1.0 + 0.6 * shade * lit, 0.0) * (1.0 - 0.5 * shade * creased * exp(-abs(r) / CREASE)), img.a);
            col = mix(col, img, mf);
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
