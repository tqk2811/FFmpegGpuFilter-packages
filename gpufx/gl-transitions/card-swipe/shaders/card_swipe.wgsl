// Port of CardSwipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CardSwipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const RADIUS: f32 = 0.045;
const AA: f32 = 0.002;

fn rounded_box(q: vec2f, b: vec2f, r: f32) -> f32 {
    let d = abs(q) - b + r;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

fn premul(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let dl = length(params.direction);
    let d = select(vec2f(0.970143, 0.242536), params.direction / dl, dl > 1e-6);
    let q = (uv - 0.5) * vec2f(ratio, 1.0);
    let b = vec2f(0.5 * ratio, 0.5);
    let p = progress;
    let h = clamp((p - 0.2) / 0.8, 0.0, 1.0);
    let g = h * h * (3.0 - 2.0 * h);
    let k = 1.0 - g;
    let sc = 1.0 - params.depth * k;
    let rb = RADIUS * min(1.0, 12.0 * k);
    let db = rounded_box(q, b * sc, rb);
    let cb = clamp(0.5 - db / max(AA * min(1.0, 40.0 * k), 1e-6), 0.0, 1.0);
    var tc = to_color(clamp(0.5 + (uv - 0.5) / sc, vec2f(0.0), vec2f(1.0)));
    tc = vec4f(tc.rgb * (1.0 - 0.35 * k * k), tc.a);
    // The cards are opaque: each one replaces what is behind it, keeping its clip alpha.
    var col = mix(premul(params.back_color), premul(tc), cb);
    let t = clamp(p / 0.75, 0.0, 1.0);
    let lift = smoothstep(0.0, 0.15, p);
    let u = min(t / 0.7, 1.0);
    let swing = u * u * (3.0 - 2.0 * u);
    let a = select(-1.3, 1.3, d.x < 0.0) * params.rotation * swing;
    let pivot = vec2f(0.0, -1.1);
    let ca = cos(a);
    let sa = sin(a);
    let swung = pivot + mat2x2f(ca, sa, -sa, ca) * -pivot;
    let far = 2.0 * length(b) + length(swung) + 0.3;
    let shift = d * far * t * t * (0.4 + 0.6 * t);
    let unrotate = mat2x2f(ca, -sa, sa, ca);
    let r = unrotate * (q - shift - pivot) + pivot;
    let rf = RADIUS * lift;
    let sh = 0.6 * lift * (1.0 - t);
    if (sh > 0.0) {
        let rs = unrotate * (q - (0.03 * d + vec2f(0.0, -0.03)) * lift - shift - pivot) + pivot;
        let ds = rounded_box(rs, b, rf);
        col = vec4f(col.rgb * (1.0 - sh * (1.0 - smoothstep(-0.05, 0.08, ds))), col.a);
    }
    let df = rounded_box(r, b, rf);
    let cf = clamp(0.5 - df / max(AA * min(1.0, 40.0 * lift), 1e-6), 0.0, 1.0);
    let fc = from_color(clamp(r / vec2f(ratio, 1.0) + 0.5, vec2f(0.0), vec2f(1.0)));
    col = mix(col, premul(fc), cf);
    if (col.a > 0.0) { return vec4f(col.rgb / col.a, col.a); }
    return vec4f(0.0);
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
