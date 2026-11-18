// Port of TileRings.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/TileRings.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const GAP: f32 = 0.035;
const EYE: f32 = 3.0;
const LIGHT: vec2f = vec2f(0.12, -0.16);

fn fmod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn ring_of(c: vec2f, dims: vec2f) -> f32 {
    return min(min(c.x, c.y), min(dims.x - 1.0 - c.x, dims.y - 1.0 - c.y));
}

// Counted counterclockwise from the ring's bottom left corner.
fn index_of(c: vec2f, r: f32, wh: vec2f) -> f32 {
    let q = c - r;
    if (q.y < 0.5) { return q.x; }
    if (q.x > wh.x - 0.5) { return wh.x + q.y; }
    if (q.y > wh.y - 0.5) { return 2.0 * wh.x + wh.y - q.x; }
    return 2.0 * (wh.x + wh.y) - q.y;
}

fn cell_at(k0: f32, r: f32, wh: vec2f) -> vec2f {
    let l = 2.0 * (wh.x + wh.y);
    let k = fmod(k0, l);
    var q: vec2f;
    if (k < wh.x) { q = vec2f(k, 0.0); }
    else if (k < wh.x + wh.y) { q = vec2f(wh.x, k - wh.x); }
    else if (k < 2.0 * wh.x + wh.y) { q = vec2f(2.0 * wh.x + wh.y - k, wh.y); }
    else { q = vec2f(0.0, l - k); }
    return q + r;
}

fn smooth3(u: f32) -> f32 { return u * u * (3.0 - 2.0 * u); }

// Overshoots by about 1.5% near the end so the ring settles like a detent.
fn ease(u: f32) -> f32 {
    let s = sin(PI * u);
    return smooth3(u) + 0.6 * u * u * u * s * s;
}

fn edge(d: f32, px: f32) -> f32 { return clamp(0.5 - d / px, 0.0, 1.0); }

fn face(s: vec2f, a: f32, dims: vec2f) -> vec4f {
    let q = clamp(s / dims, vec2f(0.0), vec2f(1.0));
    let c = select(from_color(q), to_color(q), cos(a) < 0.0);
    let sa = sin(a);
    return vec4f(c.rgb * (1.0 - 0.45 * sa * sa + 0.2 * sa * abs(cos(a))), c.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let rr = clamp(f32(params.rings), 2.0, 4.0);
    let sh = 2.0 * rr;
    let lg = max(sh, floor(sh * max(ratio, 1.0 / ratio) + 0.5));
    let dims = select(vec2f(sh, lg), vec2f(lg, sh), ratio >= 1.0);
    let pp = uv * dims;
    let here = clamp(floor(pp), vec2f(0.0), dims - 1.0);
    let px = sh / 600.0;
    let open = sin(PI * progress);
    // Resting tiles overlap by a few pixels to hide their seams.
    let hs = 0.5 - GAP * open + 2.0 * px * (1.0 - smoothstep(0.0, 0.1, open));
    let st = clamp(params.stagger, 0.0, 0.4);

    var z1 = -9.0;
    var z2 = -9.0;
    var cov1 = 0.0;
    var cov2 = 0.0;
    var a1 = 0.0;
    var a2 = 0.0;
    var s1 = pp;
    var s2 = pp;
    var shade = 0.0;
    for (var step_i = 0; step_i < 2; step_i++) {
        for (var j = 0; j < 9; j++) {
            let c = here + vec2f(f32(j % 3), f32(j / 3)) - 1.0;
            if (c.x >= 0.0 && c.y >= 0.0 && c.x < dims.x && c.y < dims.y) {
                let r = ring_of(c, dims);
                let wh = dims - 1.0 - 2.0 * r;
                let l = 2.0 * (wh.x + wh.y);
                let t = clamp((progress - st * (rr - 1.0 - r) / (rr - 1.0)) / (1.0 - st), 0.0, 1.0);
                let u1 = clamp(t / 0.34, 0.0, 1.0);
                let u2 = clamp((t - 0.66) / 0.34, 0.0, 1.0);
                let s = floor(0.25 * l + 0.5) * select(-1.0, 1.0, fmod(r, 2.0) < 0.5) * (ease(u1) - ease(u2));
                let k = index_of(c, r, wh);
                let fs = s - floor(s);
                let h = fmod(k - floor(s), l);
                let home = cell_at(h, r, wh) + 0.5;
                let ctr = mix(c, cell_at(k + 1.0, r, wh), fs) + 0.5;
                let a = PI * smooth3(smooth3(clamp((t - 0.34 - 0.2 * h / l) / 0.12, 0.0, 1.0)));
                let sa = max(sin(a), 0.0);
                let ca = cos(a);
                let ride = 0.5 * (sin(PI * u1) + sin(PI * u2));
                let lift = 0.5 * ride + sa;
                let sc = 1.0 + 0.04 * ride + 0.15 * sa;
                if (step_i == 0) {
                    // Perspective flip about the tile's vertical axis.
                    let d = (pp - ctr) / sc;
                    var den = EYE * ca + d.x * sa;
                    if (abs(den) < 1e-5) { den = 1e-5; }
                    let x = d.x * EYE / den;
                    let lp = vec2f(x, d.y * (EYE - x * sa) / EYE);
                    let ink = sc * vec2f(max(abs(ca), 0.05), 1.0);
                    let e = (abs(lp) - hs) * ink;
                    let cv = select(0.0, edge(e.x, px) * edge(e.y, px), den * ca > 0.0 || abs(ca) < 0.05);
                    let z = lift + 0.001 * cv;
                    let src = home + vec2f(select(lp.x, -lp.x, ca < 0.0), lp.y);
                    // The second clip's face lies flat in the slot under a flipping tile, so no tray shows.
                    let f = abs(pp - ctr) - hs;
                    let under = select(0.0, edge(f.x, px) * edge(f.y, px), sa > 0.0);
                    for (var m = 0; m < 2; m++) {
                        let cm = select(under, cv, m == 0);
                        let zm = select(-1.0, z, m == 0);
                        let am = select(PI, a, m == 0);
                        let sm = select(home + pp - ctr, src, m == 0);
                        if (cm > 0.0 && zm > z1) {
                            z2 = z1; cov2 = cov1; a2 = a1; s2 = s1;
                            z1 = zm; cov1 = cm; a1 = am; s1 = sm;
                        } else if (cm > 0.0 && zm > z2) {
                            z2 = zm; cov2 = cm; a2 = am; s2 = sm;
                        }
                    }
                } else if (lift > z1 + 0.01) {
                    let d = (pp - ctr - LIGHT * lift) / sc;
                    let b = abs(d * vec2f(1.0 / max(abs(ca), 0.05), 1.0)) - hs;
                    let w = length(max(b, vec2f(0.0))) + min(max(b.x, b.y), 0.0);
                    let blur = 0.04 + 0.12 * lift;
                    shade = max(shade, min(lift - max(z1, 0.0), 1.0) * (1.0 - smoothstep(-blur, blur, w)));
                }
            }
        }
    }

    var col = params.back_color;
    if (cov2 > 0.0) { col = mix(col, face(s2, a2, dims), cov2); }
    col = mix(col, face(s1, a1, dims), cov1);
    return vec4f(col.rgb * (1.0 - 0.6 * params.shadow * shade), col.a);
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
