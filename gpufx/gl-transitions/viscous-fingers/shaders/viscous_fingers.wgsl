// Port of ViscousFingers.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ViscousFingers.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const TAU: f32 = 6.2831853;
const AA: f32 = 0.0025;
const R0: f32 = 0.07;
const LIGHT: vec3f = vec3f(-0.4511, 0.5514, 0.7018);
const HALFWAY: vec3f = vec3f(-0.2445, 0.2989, 0.9224);

fn fmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn vf_hash(x: f32) -> f32 {
    var p = fract(x * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

fn vf_cap(r: f32, lim: f32, w: f32) -> f32 {
    let x = clamp((lim - r) / max(w, 1e-4), 0.0, 1.0);
    return sqrt(x * (2.0 - x));
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

// s = 2^(l + 1), passed exactly.
fn vf_split(c: f32, l: f32, s: f32) -> f32 {
    return R0 * s * (0.8 + 0.4 * vf_hash(c + 97.0 * l + 11.7));
}

// A finger of level l in cell c of n, at offset a (in cells) from the cell's middle.
fn vf_finger(l: f32, n: f32, c: f32, a: f32, r: f32, n0: f32, rt: f32, fill: f32) -> f32 {
    var g = 1.0;
    var ck = c;
    var lk = l;
    // A finger reaches no further than its ancestors, so no branch floats free.
    for (var k = 0; k < 5; k++) {
        if (lk < 0.0) { break; }
        g = min(g, 0.68 + 0.32 * vf_hash(ck + 97.0 * lk + 3.1));
        ck = floor(ck * 0.5);
        lk -= 1.0;
    }
    let split = vf_split(c, l, 2.0 * n / n0);
    let rs = select(vf_split(floor(c * 0.5), l - 1.0, n / n0) * (1.0 - 0.3 * TAU * 2.0 / n), 0.0, l < 0.5);
    let cell = TAU * r / n;
    // Children leave from their parent's middle at its full width, then settle into their own cell.
    let fork = select(smoothstep(rs, rs + 0.6 * (split - rs), r), 1.0, l < 0.5);
    let ac = select(-0.5, 0.5, fmod(c, 2.0) < 0.5) * (1.0 - fork);
    let tip = rt * mix(g, 1.0, fill);
    let w = mix(mix(0.2, 0.3, smoothstep(0.0, 0.3, tip - r)), 0.56, fill) * (2.0 - fork) * cell + 3.0 * AA * fill;
    let end = select(tip, min(tip, split + w), l < 3.5);
    return max(abs(a - ac) * cell - w * vf_cap(r, end, w), max(r - end, rs - r));
}

// Distance-like field to the air, negative inside the fingers.
fn vf_field(q: vec2f, rt: f32, fill: f32) -> f32 {
    let r = length(q);
    var th = atan2(q.y, select(1.0, q.x, dot(q, q) > 0.0)) / TAU + 0.5;
    th += (0.012 * sin(r * 11.0 + TAU * th * 3.0) + 0.007 * sin(r * 23.0 - TAU * th * 7.0)) / (0.3 + r);

    let n0 = f32(params.fingers);
    var dist = r - min(rt, R0);
    var n = n0;
    for (var l = 0; l < 5; l++) {
        let fl = f32(l);
        let x = th * n;
        let c = floor(x);
        let a = x - c - 0.5;
        let side = select(1.0, -1.0, a < 0.0);
        // The neighbour on the near side too, so the field stays continuous across cell borders.
        dist = min(dist, vf_finger(fl, n, fmod(c, n), a, r, n0, rt, fill));
        dist = min(dist, vf_finger(fl, n, fmod(c + side, n), a - side, r, n0, rt, fill));
        n *= 2.0;
    }
    return dist;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let asp = vec2f(globals.size.x / globals.size.y, 1.0);
    // The center option is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let q = (uv - center) * asp;
    let dir = q / max(length(q), 1e-4);
    let rmax = length(max(center, 1.0 - center) * asp);

    let t = progress;
    let rt = t * (rmax + 0.1) / 0.55;
    let fill = clamp((t - 0.45) / 0.55, 0.0, 1.0);
    let grow = smoothstep(0.0, 0.08, rt) * (1.0 - fill * fill);

    let eps = vec2f(0.002, 0.0);
    let d = vf_field(q, rt, fill);
    let grad = vec2f(vf_field(q + eps, rt, fill) - d, vf_field(q + eps.yx, rt, fill) - d) / eps.x;
    let gdir = grad / max(length(grad), 1e-4);

    let slope = 0.4 * exp(-max(d, 0.0) / 0.01) * grow;
    let nrm = normalize(vec3f(-slope * gdir, 1.0));
    let diffuse = max(1.0 + 0.9 * (dot(nrm, LIGHT) - LIGHT.z), 0.0);
    let spec = max(pow(max(dot(nrm, HALFWAY), 0.0), 40.0) - pow(HALFWAY.z, 40.0), 0.0);

    // Pushed radially, not away from the nearest finger, which would tear the oil along its mid-lines.
    let suv = uv - dir * 0.03 * exp(-max(d, 0.0) / 0.05) * grow / asp;
    var oil = from_color(mirror(suv));
    oil = vec4f(oil.rgb * diffuse + 0.4 * spec * oil.a, oil.a);

    var air = to_color(uv);
    air = vec4f(air.rgb * (1.0 - 0.35 * grow * exp(min(d, 0.0) / 0.006)), air.a);

    return mix(air, oil, smoothstep(-2.0 * AA, 0.0, d));
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
