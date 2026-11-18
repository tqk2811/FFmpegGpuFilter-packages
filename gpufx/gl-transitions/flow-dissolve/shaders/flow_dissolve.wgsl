// Port of FlowDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FlowDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const STEPS: i32 = 16;
const PI: f32 = 3.141592653589793;
const CELL: f32 = 0.5;
const R: f32 = 0.17;
// Core spin in radians per unit time: about 1.4 turns over the front's trace.
const GAMMA: f32 = 9.0;
const FRONT_TIME: f32 = 1.12;

fn hash(p: vec2f) -> vec3f {
    var p3 = fract(vec3f(p.xyx) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// One Gaussian vortex per cell: a line crossing it is wound into a spiral.
fn flow(x: vec2f, drift: vec2f) -> vec2f {
    let q = x / CELL;
    let i0 = floor(q);
    var v = drift;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let c = i0 + vec2f(f32(i), f32(j));
            let h = hash(c + 47.0 * params.seed);
            let r = (q - c - 0.5 - 0.4 * (h.xy - 0.5)) * CELL;
            let g = select(1.0, -1.0, h.z < 0.5) * (0.7 + 0.6 * abs(h.z - 0.5)) * exp(-dot(r, r) / (R * R));
            v += params.swirl * GAMMA * g * vec2f(-r.y, r.x);
        }
    }
    return v;
}

fn fold(p: vec2f, s: vec2f) -> vec2f {
    let u = p / s + 0.5;
    return 1.0 - abs(1.0 - (u - 2.0 * floor(u / 2.0)));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    var d = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { d = normalize(params.direction); }
    let s = vec2f(ratio, 1.0) / min(ratio, 1.0);
    let x = (uv - 0.5) * s;
    let e = progress * progress * (3.0 - 2.0 * progress);
    let ha = -params.travel * e / f32(STEPS);
    let hb = params.travel * (1.0 - e) / f32(STEPS);
    let hf = -FRONT_TIME / f32(STEPS) * sin(PI * progress);
    var xa = x;
    var xb = x;
    var xf = x;
    var a = vec4f(0.0);
    var b = vec4f(0.0);
    var wsum = 0.0;
    for (var i = 1; i <= STEPS; i++) {
        xa += ha * flow(xa, 0.5 * d);
        xb += hb * flow(xb, 0.5 * d);
        xf += hf * flow(xf + 0.5 * hf * flow(xf, vec2f(0.0)), vec2f(0.0));
        let t = f32(i) / f32(STEPS);
        // Weighted toward the far end, the point that travelled here.
        let t2 = t * t;
        let t4 = t2 * t2;
        let w = 0.02 + t4 * t4;
        let ca = from_color(fold(xa, s));
        let cb = to_color(fold(xb, s));
        a += w * vec4f(ca.rgb * ca.a, ca.a);
        b += w * vec4f(cb.rgb * cb.a, cb.a);
        wsum += w;
    }
    // A straight line across the current, advected backward: the flow winds it into curls.
    let ext = 0.5 * dot(abs(d), s) + 0.02;
    let f = mix(-ext, ext, 0.5 * (progress + e)) - dot(xf, d);
    let m = smoothstep(-0.006, 0.006, f);
    var c = mix(a, b, m) / wsum;
    c = vec4f(c.rgb * (1.0 - 0.3 * (1.0 - m) * exp(-abs(f) / 0.03) * sin(PI * progress)), c.a);
    return select(vec4f(0.0), vec4f(c.rgb / c.a, c.a), c.a > 0.0);
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
