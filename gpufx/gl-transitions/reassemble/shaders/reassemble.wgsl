// Port of Reassemble.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Reassemble.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EYE: f32 = 2.5;
// Width of the anti-aliased edges and half width of the open cracks, in frame heights.
const EDGE: f32 = 0.0015;
const CRACK: f32 = 0.005;
// The shards leave between START and START + DELAY, and each one flies for FLIGHT.
const START: f32 = 0.03;
const DELAY: f32 = 0.08;
const FLIGHT: f32 = 0.86;

fn hash3(p: vec2f) -> vec3f {
    var q = fract(vec3f(p.xyx) * vec3f(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yxz + 33.33);
    return fract((q.xxy + q.yzz) * q.zyx);
}

// The seed of the shard of grid cell g, in frame heights from the center.
fn shard_seed(g: vec2f, size: f32) -> vec2f {
    return (g + 0.5 + 0.7 * (hash3(g).xy - 0.5)) * size;
}

// Distance from q to the border of the shard of cell g (its Voronoi cell), negative outside it.
fn shard_dist(q: vec2f, g: vec2f, size: f32) -> f32 {
    let sj = shard_seed(g, size);
    var d = 1e9;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) { continue; }
            let sk = shard_seed(g + vec2f(f32(x), f32(y)), size);
            let dir = sk - sj;
            d = min(d, dot(0.5 * (sj + sk) - q, dir) / length(dir));
        }
    }
    return d;
}

fn ease(t: f32) -> f32 { return t * t * (3.0 - 2.0 * t); }

fn burst(t: f32) -> f32 {
    let u = clamp(t / 0.4, 0.0, 1.0);
    let v = clamp((t - 0.4) / 0.6, 0.0, 1.0);
    return select(1.0 - ease(v), 1.0 - (1.0 - u) * (1.0 - u), t < 0.4);
}

fn shard_color(q: vec2f, aspect: vec2f, front: f32, s: f32, rim: f32) -> vec4f {
    let src = q / aspect + 0.5;
    let img = select(to_color(src), from_color(src), front > 0.0);
    return vec4f(mix(min(img.rgb * s, vec3f(img.a)), vec3f(img.a), rim), img.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let aspect = vec2f(globals.size.x / globals.size.y, 1.0);
    let x = (uv - 0.5) * aspect;
    let size = 1.0 / clamp(f32(params.rows), 1.0, 8.0);
    let ee = clamp(params.spread, 0.0, 0.5);
    let zz = clamp(params.depth, 0.0, 1.0);
    let p = clamp(progress, 0.0, 1.0);
    let ll = normalize(vec3f(-0.45, 0.55, 1.0));
    let hh = normalize(ll + vec3f(0.0, 0.0, 1.0));
    let eye = vec3f(0.0, 0.0, EYE);
    let dir = vec3f(x, -EYE);
    let act = smoothstep(0.0, START + DELAY, p) * (1.0 - smoothstep(START + FLIGHT, 1.0, p));

    // Where this point roughly comes from, to find the shards that can cover it.
    let b0 = burst(clamp((p - START - 0.5 * DELAY) / FLIGHT, 0.0, 1.0));
    let x0 = x * (EYE - 0.75 * zz * b0) / EYE / (1.0 + ee * b0);
    let cell0 = floor(x0 / size);

    // The two nearest shards seen here: depth, clip point, side (1 front), coverage, shading, rim.
    var z1 = 1e9;
    var z2 = 1e9;
    var q1 = x;
    var q2 = x;
    var f1 = 1.0;
    var f2 = 1.0;
    var m1 = 0.0;
    var m2 = 0.0;
    var s1 = 1.0;
    var s2 = 1.0;
    var r1 = 0.0;
    var r2 = 0.0;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let g = cell0 + vec2f(f32(i), f32(j));
            let h = hash3(g + 17.0);
            let t = clamp((p - START - DELAY * h.x) / FLIGHT, 0.0, 1.0);
            let b = burst(t);
            let th = PI * ease(clamp((t - 0.1 - 0.48 * h.z) / 0.24, 0.0, 1.0));
            let ct = cos(th);
            let st = sin(th);
            let phi = PI * h.y;
            let rz = 0.5 * (h.z - 0.5) * b;
            let a0 = vec2f(cos(phi), sin(phi));
            let p0 = vec2f(-a0.y, a0.x);
            let a = vec3f(cos(phi + rz), sin(phi + rz), 0.0);
            let w = vec3f(-a.y, a.x, 0.0) * ct + vec3f(0.0, 0.0, st);
            let c = shard_seed(g, size);
            let center = vec3f(c * (1.0 + ee * b), zz * b * (0.5 + 0.5 * h.x));
            let nrm = cross(a, w);
            let den = dot(dir, nrm);
            if (abs(den) < 1e-6) { continue; }
            let lam = dot(center - eye, nrm) / den;
            if (lam <= 0.0) { continue; }
            let hit = eye + lam * dir - center;
            let u = dot(hit, a);
            let v = dot(hit, w);
            // The front carries the first clip, the back the second, mirrored so that it lands in place;
            // the side seen is the one facing the eye, which swaps where the shard is seen edge-on.
            let front = select(-1.0, 1.0, den < 0.0);
            let q = c + u * a0 + front * v * p0;
            // Anti-aliased edges, scaled to the screen; at rest the shards overlap a little to hide their seams.
            let k = EYE / (EYE - center.z);
            var e = shard_dist(q, g, size) - CRACK * act;
            let bx = 0.5 * aspect - abs(q);
            e = min(e, min(bx.x, bx.y)) * k * mix(1.0, max(abs(ct), 0.2), min(b * 8.0, 1.0)) + 4.0 * EDGE * (1.0 - act);
            let m = clamp(e / (2.0 * EDGE) + 0.5, 0.0, 1.0);
            // At rest the shards lie at the same depth: the one that covers this point fully comes first.
            let zk = lam - 0.001 * m;
            if (m <= 0.0 || zk >= z2) { continue; }
            let n = nrm * front;
            let lit = mix(0.45, 1.0, clamp(dot(n, ll) / ll.z, 0.0, 1.0));
            let glint = 0.2 * min(b * 4.0, 1.0) * pow(max(dot(n, hh), 0.0), 24.0);
            let lock = sin(PI * clamp((t - 0.86) / 0.14, 0.0, 1.0));
            let rim = (0.3 * act * min(b * 4.0, 1.0) + 0.35 * lock) * (1.0 - smoothstep(0.0, 0.006, e));
            if (zk < z1) {
                z2 = z1; q2 = q1; f2 = f1; m2 = m1; s2 = s1; r2 = r1;
                z1 = zk; q1 = q; f1 = front; m1 = m; s1 = lit + glint; r1 = rim;
            } else {
                z2 = zk; q2 = q; f2 = front; m2 = m; s2 = lit + glint; r2 = rim;
            }
        }
    }

    var col = params.back_color;
    if (m2 > 0.0) { col = mix(col, shard_color(q2, aspect, f2, s2, r2), m2); }
    if (m1 > 0.0) { col = mix(col, shard_color(q1, aspect, f1, s1, r1), m1); }
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
