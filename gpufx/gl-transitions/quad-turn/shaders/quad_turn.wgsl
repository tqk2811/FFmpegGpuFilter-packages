// Port of QuadTurn.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/QuadTurn.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const FLIP: f32 = 1.3;
// Share of the flip beat over which the wave crosses the frame; each tile flips in the rest.
const WAVE: f32 = 0.8;
const EYE: f32 = 3.0;
const AA: f32 = 0.015;
const SHADOW_OFFSET: vec2f = vec2f(0.1, -0.14);

fn fmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn rot(v: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Beats 0, 1 turn on grids offset by 0 then 1 tile; beat 2 flips; beats 3, 4 undo 1 then 0.
fn offset_of(i: f32) -> f32 { return fmod(select(4.0 - i, i, i < 2.5), 2.0); }

fn dir_of(i: f32) -> f32 { return select(-1.0, 1.0, i < 2.5); }

fn inside(lo: vec2f, size: f32, dims: vec2f) -> bool {
    return all(lo >= vec2f(0.0)) && all(lo + size <= dims);
}

fn turn(p: vec2f, i: f32, way: f32, dims: vec2f) -> vec2f {
    let o = offset_of(i);
    let lo = o + 2.0 * floor((p - o) / 2.0);
    if (!inside(lo, 2.0, dims)) { return p; }
    let c = lo + 1.0;
    return c + rot(p - c, way * dir_of(i) * 0.5 * PI);
}

fn smooth3(f: f32) -> f32 { return f * f * (3.0 - 2.0 * f); }

fn turn_angle(f: f32, c: vec2f, o: f32, dims: vec2f) -> f32 {
    let last = o + 2.0 * floor((dims - o) / 2.0) - 1.0;
    let k = c.x + 0.3 * c.y - 1.3 * (o + 1.0);
    let d = params.stagger * k / max(last.x + 0.3 * last.y - 1.3 * (o + 1.0), 1.0);
    return 0.5 * PI * smooth3(clamp((f - d) / (1.0 - params.stagger), 0.0, 1.0));
}

// A doubled smoothstep rushes through the edge-on moment.
fn flip_angle(f: f32, c: vec2f, dims: vec2f) -> f32 {
    let d = WAVE * (c.x + c.y - 1.0) / max(dims.x + dims.y - 2.0, 1.0);
    return PI * smooth3(smooth3(clamp((f - d) / (1.0 - WAVE), 0.0, 1.0)));
}

// Clamped: sin(PI) is slightly negative in float.
fn lift_of(a: f32, flip: bool) -> f32 {
    return max(select(sin(2.0 * a), sin(a), flip), 0.0);
}

// xy: point on the card relative to its center, z: lift, w: distance to its edge on screen.
fn card(pp: vec2f, c: vec2f, a: f32, flip: bool, dir: f32) -> vec4f {
    if (flip) {
        let sa = sin(a);
        let ca = cos(a);
        let s = 1.0 + 0.2 * sa;
        let d = (pp - c) / s;
        var den = EYE * ca + d.x * sa;
        if (abs(den) < 1e-5) { den = select(1e-5, -1e-5, den < 0.0); }
        let x = clamp(d.x * EYE / den, -0.5, 0.5);
        let y = d.y * (EYE - x * sa) / EYE;
        let u0 = -0.5 * ca * EYE / (EYE + 0.5 * sa);
        let u1 = 0.5 * ca * EYE / (EYE - 0.5 * sa);
        let wx = min(d.x - min(u0, u1), max(u0, u1) - d.x);
        return vec4f(select(x, -x, ca < 0.0), y, lift_of(a, true), s * min(wx, 0.5 - abs(y)));
    }
    let lift = lift_of(a, false);
    let s = 1.0 + 0.06 * lift;
    let l = rot(pp - c, -dir * a) / s;
    return vec4f(l, lift, s * (1.0 - max(abs(l.x), abs(l.y))));
}

fn layer(qq: vec2f, a: f32, flip: bool, beat: f32, dims: vec2f) -> vec4f {
    let incoming = select(beat > 2.5, cos(a) < 0.0, flip);
    var h = qq;
    if (incoming) {
        for (var i = 3; i < 5; i++) {
            if (f32(i) >= beat) { h = turn(h, f32(i), 1.0, dims); }
        }
    } else {
        for (var i = 1; i >= 0; i--) {
            if (f32(i) < beat) { h = turn(h, f32(i), -1.0, dims); }
        }
    }
    let st = clamp(h / dims, vec2f(0.0), vec2f(1.0));
    let col = select(from_color(st), to_color(st), incoming);
    let env = sin(PI * clamp(params.progress, 0.0, 1.0));
    let tf = abs(fract(qq) - 0.5);
    let seam = smoothstep(0.485, 0.5, max(tf.x, tf.y)) * env;
    var light = 1.0;
    if (flip) {
        let sa = sin(a);
        let ca = cos(a);
        light = 1.0 - 0.5 * sa * sa + 0.2 * abs(ca) * sa;
    }
    return vec4f(col.rgb * (1.0 - 0.5 * seam) * light, col.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let n = f32(params.tiles);
    let dims = select(vec2f(n, floor(n / ratio + 0.5)), vec2f(floor(n * ratio + 0.5), n), ratio >= 1.0);
    let pp = uv * dims;
    let t = progress * (4.0 + FLIP);
    let beat = select(select(min(floor(t - FLIP) + 1.0, 4.0), 2.0, t < 2.0 + FLIP), floor(t), t < 2.0);
    let start = select(beat - 1.0 + FLIP, beat, beat < 2.5);
    let flip = beat == 2.0;
    let f = clamp((t - start) / select(1.0, FLIP, flip), 0.0, 1.0);

    let size = select(2.0, 1.0, flip);
    let org = vec2f(select(offset_of(beat), 0.0, flip));
    let b0 = floor((pp - org) / size);
    let dir = dir_of(beat);

    // The two topmost cards: the second shows through the antialiased edge of the first.
    var q1 = pp;
    var q2 = pp;
    var a1 = 0.0;
    var a2 = 0.0;
    var lift1 = -1.0;
    var lift2 = -1.0;
    var cov1 = 0.0;
    var cov2 = 0.0;
    for (var j = 0; j < 9; j++) {
        let lo = org + size * (b0 + vec2f(f32(j % 3), f32(j / 3)) - 1.0);
        if (inside(lo, size, dims)) {
            let c = lo + 0.5 * size;
            let a = select(turn_angle(f, c, org.x, dims), flip_angle(f, c, dims), flip);
            let k = card(pp, c, a, flip, dir);
            if (k.w >= 0.0) {
                let cov = select(1.0, clamp(k.w / AA, 0.0, 1.0), k.z > 1e-3);
                if (k.z > lift1) {
                    q2 = q1; a2 = a1; lift2 = lift1; cov2 = cov1;
                    q1 = c + k.xy; a1 = a; lift1 = k.z; cov1 = cov;
                } else if (k.z > lift2) {
                    q2 = c + k.xy; a2 = a; lift2 = k.z; cov2 = cov;
                }
            }
        }
    }
    // Tiles outside every block of this grid stay in place, under the turning blocks.
    if (!flip && !inside(org + 2.0 * b0, 2.0, dims)) {
        if (lift1 < 0.0) {
            q1 = pp; a1 = 0.0; lift1 = 0.0; cov1 = 1.0;
        } else if (lift2 < 0.0) {
            q2 = pp; a2 = 0.0; lift2 = 0.0; cov2 = 1.0;
        }
    }

    var shade = 0.0;
    for (var j = 0; j < 9; j++) {
        let lo = org + size * (b0 + vec2f(f32(j % 3), f32(j / 3)) - 1.0);
        if (inside(lo, size, dims)) {
            let c = lo + 0.5 * size;
            let a = select(turn_angle(f, c, org.x, dims), flip_angle(f, c, dims), flip);
            let lift = lift_of(a, flip);
            if (lift > lift1 + 0.01) {
                let k = card(pp - SHADOW_OFFSET * lift, c, a, flip, dir);
                shade = max(shade, (lift - max(lift1, 0.0)) * smoothstep(select(-0.25, -0.08, flip), 0.04, k.w));
            }
        }
    }

    var col = params.back_color;
    if (flip) { col = layer(pp, PI, true, beat, dims); }
    if (lift2 >= 0.0) { col = mix(col, layer(q2, a2, flip, beat, dims), cov2); }
    if (lift1 >= 0.0) { col = mix(col, layer(q1, a1, flip, beat, dims), cov1); }
    return vec4f(col.rgb * (1.0 - params.shadow * 0.7 * shade), col.a);
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
