// Port of GridFlip.glsl from gl-transitions (author: TimDonselaar, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GridFlip.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0012;
// Distance of the eye from each tile, in tile sizes.
const EYE: f32 = 2.2;
// Part of the flips during which the last tile waits for its turn.
const STAGGER: f32 = 0.55;
// Light direction (x, y over z): from the upper left, in front of the frame.
const LIGHT: vec2f = vec2f(-0.45, 0.3);

fn hash12(v: vec2f) -> f32 {
    var v3 = fract(vec3f(v.x, v.y, v.x) * 0.1031);
    v3 += dot(v3, v3.yzx + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

fn ease_in_out(t: f32) -> f32 { return mix(t, t * t * (3.0 - 2.0 * t), 0.7); }

fn pause_part() -> f32 { return clamp(params.pause, 0.05, 0.4); }

// The turn of a tile, 0 showing the first clip to 1 showing the second, at q the progress
// of the flips and with stagger the delay of the last tile.
fn flip_time(cell: vec2f, grid: vec2f, q: f32, stagger: f32) -> f32 {
    let wave = (cell.x + (grid.y - 1.0 - cell.y)) / max(grid.x + grid.y - 2.0, 1.0);
    let order = mix(wave, hash12(cell + 7.31), clamp(params.randomness, 0.0, 1.0));
    return ease_in_out(clamp((q - order * stagger) / (1.0 - stagger), 0.0, 1.0));
}

fn aa(d: f32, e: f32) -> f32 { return clamp(d / max(2.0 * e, 1e-6) + 0.5, 0.0, 1.0); }

fn box_shadow(p: vec2f, half_size: vec2f, blur: f32) -> f32 {
    let d = abs(p) - half_size;
    let dist = length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
    return 1.0 - smoothstep(-blur, blur, dist);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let grid = max(round(params.size), vec2f(1.0));
    let frame = vec2f(ratio, 1.0);
    let tile = frame / grid;
    let cell = clamp(floor(uv * grid), vec2f(0.0), grid - 1.0);
    let pos = uv * frame;
    let ppart = pause_part();
    let gap_open = smoothstep(0.0, ppart, progress) * (1.0 - smoothstep(1.0 - ppart, 1.0, progress));
    let min_side = min(tile.x, tile.y);
    let gap = clamp(params.divider_width, 0.0, 0.4) * min_side * gap_open;
    let half_tile = 0.5 * tile - gap;
    let eye = EYE * max(tile.x, tile.y);
    // The flips start while the gaps finish opening, and end while they start closing.
    let pp = 0.6 * ppart;
    let fq = clamp((progress - pp) / (1.0 - 2.0 * pp), 0.0, 1.0);
    let stagger = select(0.0, STAGGER, grid.x * grid.y > 1.5);
    var c1 = vec4f(0.0);
    var c2 = vec4f(0.0);
    var m1 = 0.0;
    var m2 = 0.0;
    var z1 = 1e9;
    var z2 = 1e9;
    var rest1 = true;
    var rest2 = true;
    var shadow_bg = 0.0;
    var shadow_flip = 0.0;
    for (var j = -1; j <= 1; j++) {
        for (var i = -1; i <= 1; i++) {
            let nc = cell + vec2f(f32(i), f32(j));
            if (nc.x < 0.0 || nc.y < 0.0 || nc.x > grid.x - 1.0 || nc.y > grid.y - 1.0) { continue; }
            let t = flip_time(nc, grid, fq, stagger);
            var ca = cos(PI * t);
            var sa = sin(PI * t);
            let rest = t <= 0.0 || t >= 1.0;
            if (rest) {
                ca = select(-1.0, 1.0, t <= 0.0);
                sa = 0.0;
            }
            let center = (nc + 0.5) * tile;
            let q = pos - center;
            let lift = 0.05 * gap_open * min_side + 0.35 * half_tile.x * sa;
            let sh_offset = -LIGHT * lift;
            let sh_half = vec2f(half_tile.x * abs(ca) + 0.5 * lift, half_tile.y);
            let sh = box_shadow(q - sh_offset, sh_half, 0.01 * min_side + 0.5 * lift);
            shadow_bg = 1.0 - (1.0 - shadow_bg) * (1.0 - 0.45 * gap_open * sh);
            shadow_flip = max(shadow_flip, 0.45 * sa * sa * sh);
            // Ray from the eye in front of the tile center to the tile turned around its vertical axis.
            let den = eye * ca - q.x * sa;
            if (abs(den) < 1e-6) { continue; }
            let s = eye * ca / den;
            if (s <= 0.0) { continue; }
            let hit = vec3f(s * q.x, s * q.y, eye * (1.0 - s));
            let u = hit.x * ca - hit.z * sa;
            let xa = half_tile.x * ca * eye / (eye + half_tile.x * sa);
            let xb = -half_tile.x * ca * eye / (eye - half_tile.x * sa);
            let dx = min(q.x - min(xa, xb), max(xa, xb) - q.x);
            let dy = (half_tile.y - abs(hit.y)) / s;
            // Soft edges, except where the tiles touch each other.
            let e = max(min(EDGE, gap), EDGE * min(8.0 * sa, 1.0));
            let m = aa(min(dx, dy), e);
            if (m <= 0.0) { continue; }
            let front = ca > 0.0;
            let src = (center + vec2f(select(-u, u, front), hit.y)) / frame;
            var col = select(to_color(src), from_color(src), front);
            if (!rest) {
                let nx = select(-sa, sa, front);
                let lit = abs(ca) + nx * LIGHT.x;
                var rgb = col.rgb * (mix(0.35, 1.0, clamp(lit, 0.0, 1.0)) + 0.25 * max(lit - 1.0, 0.0));
                rgb += 0.12 * sa * (1.0 - smoothstep(0.0, 3.0 * EDGE, min(dx, dy)));
                col = vec4f(rgb, col.a);
            }
            if (s < z1) {
                c2 = c1; m2 = m1; z2 = z1; rest2 = rest1;
                c1 = col; m1 = m; z1 = s; rest1 = rest;
            } else if (s < z2) {
                c2 = col; m2 = m; z2 = s; rest2 = rest;
            }
        }
    }
    var color = params.bg_color;
    color = vec4f(color.rgb * (1.0 - clamp(max(shadow_bg, shadow_flip), 0.0, 1.0)), color.a);
    if (rest2) { c2 = vec4f(c2.rgb * (1.0 - shadow_flip), c2.a); }
    if (rest1) { c1 = vec4f(c1.rgb * (1.0 - shadow_flip), c1.a); }
    color = mix(color, c2, m2);
    return mix(color, c1, m1);
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
