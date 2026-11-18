// Port of LightningFlash.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LightningFlash.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// The bolts crack down until this time, then the strobes start.
const LEADER: f32 = 0.3;

var<private> g_ratio: f32;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// A value noise that is linear between its cells: a jagged polyline, centered on 0.
fn jag(s: f32, k: f32) -> f32 {
    let i = floor(s);
    return mix(hash(vec2f(i, k)), hash(vec2f(i + 1.0, k)), fract(s)) - 0.5;
}

fn zigzag(y: f32, k: f32) -> f32 {
    return min(g_ratio, 1.0) * (0.15 * jag(y * 5.0, k) + 0.06 * jag(y * 13.0, k + 1.0) + 0.03 * jag(y * 31.0, k + 2.0) + 0.012 * jag(y * 67.0, k + 3.0));
}

// The x of a bolt at height y: from x0 at the top (y = 1) to x1 at its end (y = y1), given z0 and
// z1, its zigzag at both ends.
fn bolt_x(y: f32, x0: f32, x1: f32, y1: f32, z0: f32, z1: f32, k: f32) -> f32 {
    let t = (1.0 - y) / (1.0 - y1);
    return mix(x0 - z0, x1 - z1, t) + zigzag(y, k);
}

// The x of a branch at height y: it leaves its bolt at (xb, yb), where its own zigzag is zb, and
// drifts sideways by dir per unit of height.
fn branch_x(y: f32, xb: f32, yb: f32, zb: f32, dir: f32, k: f32) -> f32 {
    return xb + dir * (yb - y) + 0.6 * (zigzag(y, k) - zb);
}

// Distance to a curve x = f(y), knowing its x and its slope at the pixel's height, and how far
// above or below its ends the pixel is; the slope only corrects the distance close to the curve,
// so the glow farther away does not streak along the zigzags.
fn curve_dist(q: vec2f, x: f32, slope: f32, outside: f32) -> f32 {
    let dx = abs(q.x - x);
    let d = dx * mix(inverseSqrt(1.0 + slope * slope), 1.0, smoothstep(0.0, 0.08, dx));
    return length(vec2f(d, max(outside, 0.0)));
}

// A strobe at time t0: a quick rise, a plateau of length hold, then a decay.
fn pulse(p: f32, t0: f32, hold: f32, decay: f32) -> f32 {
    let x = p - t0;
    if (x < 0.0) { return smoothstep(-0.012, 0.0, x); }
    return exp(-max(x - hold, 0.0) / decay);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_ratio = globals.size.x / globals.size.y;
    let ratio = g_ratio;
    let color = params.color.rgb;
    let p = progress;
    let q = vec2f(uv.x * ratio, uv.y);
    // (Seeds far apart, so that neighboring seeds share no hash keys.)
    let k0 = floor(params.seed) * 61.0;
    let nb = clamp(params.bolts, 1, 3);
    let nf = clamp(params.flashes, 1, 4);
    // The clips switch during the brightest strobe, the second one (or the only one).
    let cut = select(0, 1, nf > 1);

    var flash = 0.0;
    var lit = 0.0;
    var t_cut = LEADER;
    var t_last = LEADER;
    var t = LEADER;
    for (var i = 0; i < 4; i++) {
        if (i < nf) {
            let is_cut = i == cut;
            var amp = 1.0;
            if (!is_cut) { amp = select(0.7 * pow(0.75, f32(i - cut - 1)), 0.55, i < cut); }
            let s = amp * pulse(p, t, select(0.004, 0.025, is_cut), select(0.022, 0.03, is_cut));
            flash = max(flash, s);
            lit = max(lit, pulse(p, t, 0.01, 0.045));
            if (is_cut) { t_cut = t; }
            t_last = t;
            t += select(0.08, 0.12, is_cut) + 0.04 * hash(vec2f(f32(i), k0 + 5.0));
        }
    }
    let stutter = mix(0.7, 1.0, hash(vec2f(floor(p * 70.0), k0 + 9.0)));
    flash *= stutter;
    let whiteout = pulse(p, t_cut, 0.025, 0.02);
    var tail = 0.0;
    if (p > t_last) { tail = exp(-(p - t_last) / 0.1) * smoothstep(0.03, 0.06, p - t_last); }
    flash = max(flash, 0.35 * tail * step(0.45, hash(vec2f(floor(p * 40.0), k0 + 13.0))));

    var grow = clamp(p / LEADER, 0.0, 1.0);
    grow = (floor(grow * 7.0) + smoothstep(0.0, 1.0, fract(grow * 7.0))) / 7.0;
    let faint = 0.5 * mix(0.6, 1.0, hash(vec2f(floor(p * 50.0), k0 + 11.0)));
    var bolt_light = max(lit * stutter, faint * exp(-(p - LEADER) / 0.12));
    if (p < LEADER) { bolt_light = faint * smoothstep(0.0, 0.06, p); }
    bolt_light = max(bolt_light, 0.6 * flash * tail);
    bolt_light *= 1.0 - smoothstep(t_last + 0.1, t_last + 0.3, p);

    var core = 0.0;
    var halo = 0.0;
    var near = 10.0;
    let lights_on = bolt_light > 0.0 || flash > 0.0;
    for (var b = 0; b < 3; b++) {
        if (b < nb && lights_on) {
            let fb = f32(b);
            let kb = k0 + fb * 17.0;
            var x1 = params.strike * ratio;
            var y1 = -0.05;
            var bright = 1.0;
            if (b > 0) {
                let roomy = select(-1.0, 1.0, params.strike < 0.5);
                let cramped = min(params.strike, 1.0 - params.strike) < 0.25;
                let side = select(-roomy, roomy, b == 1 || cramped);
                let dist = select(0.22, 0.5, b == 2 && cramped);
                x1 = clamp(x1 + side * ratio * (dist + 0.12 * hash(vec2f(fb, kb))), 0.08 * ratio, 0.92 * ratio);
                y1 = 0.25 + 0.25 * hash(vec2f(fb, kb + 1.0));
                bright = 0.7;
            }
            let x0 = clamp(x1 + (hash(vec2f(fb, kb + 2.0)) - 0.5) * 0.5 * min(ratio, 1.0), 0.1 * ratio, 0.9 * ratio);
            let tip = mix(1.02, y1, grow);
            // (The slope is measured over a few pixels, so it changes smoothly at the corners.)
            let e = 0.01;
            let z0 = zigzag(1.0, kb);
            let z1 = zigzag(y1, kb);
            let x = bolt_x(q.y, x0, x1, y1, z0, z1, kb);
            let slope = (bolt_x(q.y + e, x0, x1, y1, z0, z1, kb) - bolt_x(q.y - e, x0, x1, y1, z0, z1, kb)) / (2.0 * e);
            let d = curve_dist(q, x, slope, max(max(y1, tip) - q.y, q.y - 1.05));
            near = min(near, d);
            let w = 0.003 * mix(1.0, 0.7, fb / 2.0);
            core += bright * exp(-d * d / (w * w));
            halo += bright * (0.7 * exp(-d * 24.0) + 0.25 * exp(-d * 6.0));
            for (var j = 0; j < 3; j++) {
                let fj = f32(j);
                let kj = kb + 3.0 + fj * 5.0;
                let tb = 0.12 + 0.2 * fj + 0.15 * hash(vec2f(fj, kj));
                let yb = mix(1.0, y1, tb);
                let len = (0.3 + 0.25 * hash(vec2f(fj, kj + 1.0))) * (1.0 - tb) * (1.0 - y1);
                let dir = select(1.0, -1.0, j == 1) * (0.2 + 0.45 * hash(vec2f(fj, kj + 2.0))) * min(ratio, 1.0);
                let xb = bolt_x(yb, x0, x1, y1, z0, z1, kb);
                let zb = zigzag(yb, kj);
                let bx = branch_x(q.y, xb, yb, zb, dir, kj);
                let bs = (branch_x(q.y + e, xb, yb, zb, dir, kj) - branch_x(q.y - e, xb, yb, zb, dir, kj)) / (2.0 * e);
                let bd = curve_dist(q, bx, bs, max(max(yb - len, tip) - q.y, q.y - yb));
                near = min(near, bd);
                let along = clamp((yb - q.y) / len, 0.0, 1.0);
                let fade = bright * (1.0 - 0.8 * along);
                let bw = w * mix(0.8, 0.4, along);
                core += fade * exp(-bd * bd / (bw * bw));
                halo += fade * 0.6 * (0.7 * exp(-bd * 24.0) + 0.25 * exp(-bd * 6.0));
            }
        }
    }

    let m = smoothstep(t_cut, t_cut + 0.025, p);
    var c = vec4f(0.0);
    if (m < 1.0) {
        let a = from_color(uv);
        c += (1.0 - m) * vec4f(a.rgb * a.a, a.a);
    }
    if (m > 0.0) {
        let a = to_color(uv);
        c += m * vec4f(a.rgb * a.a, a.a);
    }
    if (c.a <= 0.0) { return vec4f(0.0); }
    var col = c.rgb / c.a;

    let live = smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(0.85, 1.0, p));
    let dim = 0.4 * smoothstep(0.0, LEADER, p) * (1.0 - smoothstep(t_cut, t_last + 0.15, p));
    let f = flash * mix(0.6 + 0.4 * exp(-near * 4.0), 1.0, smoothstep(0.6, 1.0, flash));
    col *= 1.0 - dim * live;
    col = col * (1.0 + 2.5 * f * live) + color * (1.1 * f * live);
    let g = 0.4 + 1.2 * params.glow;
    let light = mix(color, vec3f(1.0), 0.75) * min(core, 1.5) * 1.6 + color * g * halo;
    col += light * bolt_light * live;
    col = mix(col, vec3f(1.0), 0.92 * whiteout * live);
    return vec4f(clamp(col, vec3f(0.0), vec3f(1.0)), c.a);
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
