// Port of Unstack.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Unstack.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PULL: f32 = 0.11;
const FALL: f32 = 0.1;
// The stack starts to fall once the pulled band has nearly cleared its slot.
const LAG: f32 = 0.85;
const IMPACT: f32 = 0.62;
// Past 1 so the smeared tail has left the frame too.
const REACH: f32 = 1.3;
const EDGE: f32 = 0.0015;
const TAPS: i32 = 16;

fn hash(n: f32) -> f32 {
    var p = fract(vec2f(n) * vec2f(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}

fn count() -> f32 { return clamp(f32(params.bands), 2.0, 12.0); }

fn rank(i: f32, n: f32) -> f32 {
    var r = 0.0;
    let hi = hash(i + 7.0);
    for (var j = 0; j < 12; j++) {
        if (f32(j) >= n) { break; }
        let h = hash(f32(j) + 7.0);
        if (h < hi || (h == hi && f32(j) < i)) { r += 1.0; }
    }
    return r;
}

fn start_time(r: f32, n: f32) -> f32 {
    return 0.02 + r * (0.96 - LAG * PULL - FALL) / (n - 1.0);
}

fn pull_phase(t0: f32) -> f32 { return clamp((params.progress - t0) / PULL, 0.0, 1.0); }

fn pull_offset(u: f32, r: f32) -> f32 {
    return select(-1.0, 1.0, r - 2.0 * floor(r / 2.0) < 0.5) * REACH * u * u;
}

fn hump(s: f32) -> f32 { return 4.0 * s * (1.0 - s); }

fn drop_of(t0: f32) -> f32 {
    let t = clamp((params.progress - t0 - LAG * PULL) / FALL, 0.0, 1.0);
    if (t < IMPACT) { return (t / IMPACT) * (t / IMPACT); }
    // Two rebounds, the second a third as high and shorter.
    let s = (t - IMPACT) / (1.0 - IMPACT);
    let h = select(0.3 * hump((s - 0.6) / 0.4), hump(s / 0.6), s < 0.6);
    return 1.0 - 0.2 * clamp(params.bounce, 0.0, 1.0) * h;
}

fn box(v: f32, a: f32, b: f32, soft: f32) -> f32 {
    return smoothstep(a - soft, a + soft, v) * (1.0 - smoothstep(b - soft, b + soft, v));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let n = count();
    let hh = 1.0 / n;
    var c = vec4f(0.0);
    var covered = 0.0;
    var above = 1.0;
    var below = 1.0;
    var front = vec4f(0.0);
    var front_a = 0.0;
    var shadow = 1.0;
    var dd = 0.0;
    var floor_y = 0.0;
    for (var k = 0; k < 24; k++) {
        let j = f32(k);
        if (j >= 2.0 * n) { break; }
        let b = (j - dd) * hh;
        let y = uv.y - b;
        var u = 0.0;
        var r = 0.0;
        var t0 = 0.0;
        if (j < n) {
            r = rank(j, n);
            t0 = start_time(r, n);
            u = pull_phase(t0);
        }
        if (u > 0.0) {
            let x = pull_offset(u, r);
            let lift = smoothstep(0.0, 0.35, u);
            let off = 0.22 * hh * lift;
            let grow = 1.0 + 0.08 * lift;
            shadow *= 1.0 - 0.55 * lift * box(uv.x - x - sign(x) * off * 0.4, 0.0, 1.0, off)
                * box(uv.y + off - b - 0.5 * hh, -0.5 * hh * grow, 0.5 * hh * grow, off);
            // A lifted band is closer to the eye, so it looks a bit taller.
            var ly = (y - 0.5 * hh) / grow + 0.5 * hh;
            let ya = clamp(min(ly, hh - ly) / (EDGE * lift + 1e-5) + 0.5, 0.0, 1.0);
            // Smear over the distance travelled in about half a frame.
            let v = sign(x) * max(min(0.012 * 2.0 * REACH * u / PULL, 0.1), EDGE);
            let s0 = uv.x - x;
            let lo = min(s0, s0 + v);
            let hi = max(s0, s0 + v);
            let a = ya * max(min(hi, 1.0) - max(lo, 0.0), 0.0) / abs(v);
            if (a > 0.0) {
                ly = clamp(ly, 0.0, hh);
                var sum = vec4f(0.0);
                for (var m = 0; m < TAPS; m++) {
                    let t = from_color(vec2f(mix(max(lo, 0.0), min(hi, 1.0), (f32(m) + 0.5) / f32(TAPS)), j * hh + ly));
                    sum += vec4f(t.rgb * t.a, t.a);
                }
                var band = vec4f(sum.rgb / max(sum.a, 1e-6), sum.a / f32(TAPS));
                band = vec4f(band.rgb * (1.0 - 0.3 * lift * (1.0 - smoothstep(0.0, 0.2 * hh, min(ly, hh - ly)))), band.a);
                front = mix(front, band, select(1.0, a, front_a > 0.0));
                front_a = a + front_a * (1.0 - a);
            }
        } else {
            // Only edges facing an open gap are softened, and only inside it, so closed seams stay exact.
            let e = max(min(EDGE, 0.5 * (b - floor_y)), 0.0) + 1e-6;
            let m = clamp(y / e + 1.0, 0.0, 1.0) * step(y, hh);
            if (m > 0.0) {
                var img: vec4f;
                if (j < n) {
                    img = from_color(vec2f(uv.x, j * hh + max(y, 0.0)));
                } else {
                    img = to_color(vec2f(uv.x, (j - n) * hh + max(y, 0.0)));
                }
                c = mix(c, img, select(1.0, m, covered > 0.0));
                covered = max(covered, m);
            }
            if (y < 0.0) { above = min(above, -y); }
            if (y > hh) { below = min(below, y - hh); }
            floor_y = b + hh;
        }
        if (j < n) { dd += drop_of(t0); }
    }
    let gap = vec4f(params.slot.rgb * (1.0 - 0.65 * exp(-above / (0.2 * hh))) * (1.0 - 0.35 * exp(-below / (0.1 * hh))), params.slot.a);
    c = mix(gap, c, covered);
    c = vec4f(c.rgb * shadow, c.a);
    return mix(c, front, front_a);
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
