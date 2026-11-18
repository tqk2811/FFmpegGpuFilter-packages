// Port of GlitterDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitterDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Share of the transition each tile takes to flip over.
const FLIP: f32 = 0.28;
const LIFT: f32 = 0.3;
const EDGE: f32 = 0.04;
// The grid is shifted off the pixel centers, so no pixel sits right on the border of two tiles.
const SHIFT: vec2f = vec2f(0.37, 0.21);
const PI: f32 = 3.14159265;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn modv(v: vec2f, s: vec2f) -> vec2f { return v - s * floor(v / s); }

// Folds uv back into 0..1, so the tiles on the border of the frame stay filled.
fn mirrored(v: vec2f) -> vec2f {
    let m = modv(v, vec2f(2.0));
    return mix(m, 2.0 - m, step(vec2f(1.0), m));
}

fn flip_of(id: vec2f, progress: f32) -> f32 {
    let t = clamp((progress - hash12(id) * (1.0 - FLIP)) / FLIP, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

fn axis_of(id: vec2f) -> vec2f {
    let a = 2.0 * PI * hash12(id + 41.7);
    return vec2f(cos(a), sin(a));
}

// The point of the flat tile seen at offset s from its center, through the foreshortening and the lift.
fn unproject(s: vec2f, n: vec2f, f: f32) -> vec2f {
    let c = abs(cos(PI * f));
    let along = dot(s, n);
    return (s + n * (along / max(c, 1e-4) - along)) / (1.0 + LIFT * sin(PI * f));
}

// 0.5 on the edges of a tile one unit tall: a diamond one unit wide, or a flat-top hexagon.
fn shape(v0: vec2f) -> f32 {
    let v = abs(v0);
    if (params.hexagons != 0u) { return max(v.y, dot(v, vec2f(0.8660254, 0.5))); }
    return v.x + v.y;
}

fn id_of(center: vec2f) -> vec2f {
    // The centers sit on multiples of (0.866, 0.5) for hexagons, of (0.5, 0.5) for diamonds.
    let grid = select(vec2f(2.0), vec2f(1.1547005, 2.0), params.hexagons != 0u);
    return floor(center * grid + 0.5) + vec2f(13.0, 7.0) * floor(params.seed) + 3.0;
}

fn cover_of(p: vec2f, center: vec2f, progress: f32) -> f32 {
    let id = id_of(center);
    let f = flip_of(id, progress);
    if (f <= 0.0 || f >= 1.0) { return 0.0; }
    let z = sin(PI * f);
    let on_screen = (1.0 + LIFT * z) * max(abs(cos(PI * f)), 0.15);
    // The edge softens in as the tile starts turning, so that nothing pops.
    let edge = EDGE * min(1.0, 4.0 * z) + 1e-4;
    return clamp((0.5 - shape(unproject(p - center, axis_of(id), f))) * on_screen / edge, 0.0, 1.0);
}

fn tile_color(p: vec2f, center: vec2f, progress: f32, ratio: f32) -> vec4f {
    let id = id_of(center);
    let f = flip_of(id, progress);
    let n = axis_of(id);
    let c = cos(PI * f);
    let z = sin(PI * f);
    let s0 = unproject(p - center, n, f);
    let suv = mirrored((center + s0 - SHIFT) / params.tiles / vec2f(ratio, 1.0) + 0.5);
    var col = to_color(suv);
    if (c > 0.0) { col = from_color(suv); }
    let nrm = normalize(vec3f(n * z * select(1.0, -1.0, c < 0.0) + 0.5 * s0, abs(c)));
    let l = normalize(vec3f(-0.3, 0.4, 1.0));
    let shade = 0.45 + 0.55 * clamp(dot(nrm, l) / l.z, 0.0, 1.6);
    let hv = normalize(vec3f(-0.45, 0.55, 1.0));
    let spec = smoothstep(0.94, 0.995, dot(nrm, hv)) * 2.0 + pow(1.0 - abs(c), 6.0) * 0.6;
    let light = clamp(params.glint.rgb * params.sparkle * spec * z, vec3f(0.0), vec3f(1.0));
    let base = clamp(col.rgb * mix(1.0, shade, z), vec3f(0.0), vec3f(1.0));
    return vec4f(base + light - base * light, col.a);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let hexagons = params.hexagons != 0u;
    // In units where the tiles are one unit tall.
    let p = (uv - 0.5) * vec2f(ratio, 1.0) * params.tiles + SHIFT;
    var home: vec2f;
    if (hexagons) {
        let s = vec2f(1.7320508, 1.0);
        let a = modv(p, s) - 0.5 * s;
        let b = modv(p - 0.5 * s, s) - 0.5 * s;
        home = select(p - b, p - a, dot(a, a) < dot(b, b));
    } else {
        let q = floor(vec2f(p.x + p.y, p.y - p.x)) + 0.5;
        home = vec2f(q.x - q.y, q.x + q.y) * 0.5;
    }

    // What lies under the flipping tiles: the picture while the own tile rests, else the backing.
    let f_home = flip_of(id_of(home), progress);
    var under = params.back_color;
    if (f_home <= 0.0) { under = from_color(uv); } else if (f_home >= 1.0) { under = to_color(uv); }

    // The two topmost flipping tiles at the pixel, among its own and the lifted neighbours reaching
    // over it: the higher a tile is in its flip, the closer it is to the viewer.
    var z1 = -1.0;
    var z2 = -1.0;
    var cover1 = 0.0;
    var cover2 = 0.0;
    var center1 = home;
    var center2 = home;
    for (var k = 0; k < 9; k++) {
        let fk = f32(k);
        var off: vec2f;
        if (hexagons) {
            if (k > 6) { break; }
            if (k == 0) { off = vec2f(0.0); }
            else if (k < 3) { off = vec2f(0.0, fk * 2.0 - 3.0); }
            else { off = vec2f((fk - 2.0 * floor(fk / 2.0)) * 1.7320508 - 0.8660254, select(0.5, -0.5, fk < 5.0)); }
        } else {
            let o = vec2f(fk - 3.0 * floor(fk / 3.0) - 1.0, floor(fk / 3.0) - 1.0);
            off = vec2f(o.x - o.y, o.x + o.y) * 0.5;
        }
        let center = home + off;
        let cover = cover_of(p, center, progress);
        if (cover <= 0.0) { continue; }
        let z = sin(PI * flip_of(id_of(center), progress));
        if (z > z1) {
            z2 = z1;
            cover2 = cover1;
            center2 = center1;
            z1 = z;
            cover1 = cover;
            center1 = center;
        } else if (z > z2) {
            z2 = z;
            cover2 = cover;
            center2 = center;
        }
    }
    if (z1 < 0.0) { return under; }
    var c = under;
    if (z2 >= 0.0 && cover1 < 1.0) { c = mix(c, tile_color(p, center2, progress, ratio), cover2); }
    return mix(c, tile_color(p, center1, progress, ratio), cover1);
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
