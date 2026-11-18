// Port of Shatter.glsl from gl-transitions (author: lbl, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Shatter.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Distance from the camera to the pane, as a part of the frame height.
const EYE: f32 = 2.5;
// How far the shard corners are moved from a regular grid, as a part of a cell.
const JITTER: f32 = 0.32;
const EDGE: f32 = 0.0012;
const CRACK_WIDTH: f32 = 0.0025;
const BEVEL: f32 = 0.006;

fn hash32(p: vec2f) -> vec3f {
    var p3 = fract(vec3f(p.x, p.y, p.x) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

fn cell_size() -> f32 { return 1.0 / clamp(params.shards, 3.0, 8.0); }

fn seed_offset() -> vec2f { return vec2f(37.0, 17.0) * floor(params.seed); }

fn corner(p: vec2f) -> vec2f {
    return (p + JITTER * (2.0 * hash32(p + seed_offset()).xy - 1.0)) * cell_size();
}

// Signed distance from q to the line a -> b, positive on its left.
fn side(q: vec2f, a: vec2f, b: vec2f) -> f32 {
    let d = b - a;
    return (d.x * (q.y - a.y) - d.y * (q.x - a.x)) / length(d);
}

fn diagonal_up(c: vec2f) -> bool { return hash32(c + seed_offset() + 0.5).z > 0.5; }

// Distance from q to the edges of the triangle p0 p1 p2 (counterclockwise), positive inside.
fn triangle_dist(q: vec2f, p0: vec2f, p1: vec2f, p2: vec2f) -> f32 {
    return min(min(side(q, p0, p1), side(q, p1, p2)), side(q, p2, p0));
}

// The shard that holds q on the unbroken pane: (its cell, its triangle, the distance to its nearest crack).
fn locate(q: vec2f) -> vec4f {
    var c = floor(q / cell_size());
    // The cell sides are not straight: step to the neighbor cell when q is beyond one of them.
    for (var i = 0; i < 2; i++) {
        var a = corner(c);
        var b = corner(c + vec2f(1.0, 0.0));
        var cc = corner(c + 1.0);
        var d = corner(c + vec2f(0.0, 1.0));
        c.x += select(select(0.0, 1.0, side(q, b, cc) < 0.0), -1.0, side(q, d, a) < 0.0);
        a = corner(c);
        b = corner(c + vec2f(1.0, 0.0));
        cc = corner(c + 1.0);
        d = corner(c + vec2f(0.0, 1.0));
        c.y += select(select(0.0, 1.0, side(q, cc, d) < 0.0), -1.0, side(q, a, b) < 0.0);
    }
    let a = corner(c);
    let b = corner(c + vec2f(1.0, 0.0));
    let cc = corner(c + 1.0);
    let d = corner(c + vec2f(0.0, 1.0));
    let up = diagonal_up(c);
    let d0 = select(triangle_dist(q, a, b, d), triangle_dist(q, a, b, cc), up);
    let d1 = select(triangle_dist(q, b, cc, d), triangle_dist(q, a, cc, d), up);
    return vec4f(c, select(0.0, 1.0, d1 > d0), abs(max(d0, d1)));
}

// Rodrigues rotation of v around the unit axis k.
fn rotate(v: vec3f, k: vec3f, angle: f32) -> vec3f {
    let c = cos(angle);
    let s = sin(angle);
    return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

// The time a shard breaks loose: the nearer the impact the sooner, and late enough to fall
// out of the frame by the end (dn: its distance to the impact, as a part of the reach).
fn release_time(mid: vec2f, dn: f32, h: f32, g: f32, margin: f32) -> f32 {
    let latest = max(0.98 - sqrt(2.0 * (mid.y + margin) / g), 0.04);
    return 0.04 + (latest - 0.04) * (0.8 * pow(dn, 0.8) + 0.2 * h);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let s = cell_size();
    let a = vec2f(uv.x * ratio, uv.y);
    let eye = vec3f(0.5 * ratio, 0.5, -EYE);
    let ray = vec3f(a, 0.0) - eye;
    let light = normalize(vec3f(-0.35, 0.55, -1.0));
    let halfway = normalize(light - normalize(ray));
    let g = 12.0 * clamp(params.gravity, 0.5, 3.0);
    // `center` is given y down.
    let imp = clamp(vec2f(params.center.x, 1.0 - params.center.y), vec2f(0.0), vec2f(1.0)) * vec2f(ratio, 1.0);
    let rch = length(max(imp, vec2f(ratio, 1.0) - imp));
    let margin = 0.1 + 1.5 * s;
    // The cracks run from the impact to the farthest corner before the last shards break loose.
    let crack_time = clamp(0.6 * (0.94 - sqrt(2.0 * (1.0 + margin) / g)), 0.05, 0.22);
    var pane = vec4f(0.0);
    var pane_depth = 1e9;
    let here = locate(a);
    let hc = here.xy;
    let ha = corner(hc);
    let hb = corner(hc + vec2f(1.0, 0.0));
    let hcc = corner(hc + 1.0);
    let hd = corner(hc + vec2f(0.0, 1.0));
    let hup = diagonal_up(hc);
    var hcenter = select(select(hb + hcc + hd, ha + hcc + hd, hup), select(ha + hb + hd, ha + hb + hcc, hup), here.z < 0.5);
    let hh = hash32(hc + vec2f(0.31, 0.57) * (here.z + 1.0) + seed_offset());
    hcenter /= 3.0;
    if (progress < release_time(hcenter, clamp(length(hcenter - imp) / rch, 0.0, 1.0), hh.x, g, margin)) {
        var col = from_color(uv);
        let crack = clamp((progress - crack_time * length(a - imp) / rch) / 0.03, 0.0, 1.0);
        // Cracked shards settle at slightly different angles.
        let n = rotate(vec3f(0.0, 0.0, -1.0), normalize(vec3f(hh.yz - 0.5, 0.0) + 1e-4), 0.06 * crack * (hh.x - 0.5));
        var rgb = col.rgb * (1.0 + 1.2 * (dot(n, light) + light.z));
        rgb += crack * 0.35 * pow(max(dot(n, halfway), 0.0), 400.0) * col.a;
        let line = crack * (1.0 - smoothstep(0.0, CRACK_WIDTH, here.w));
        rgb = mix(rgb, vec3f(0.95, 0.98, 1.0) * col.a, 0.85 * line);
        pane = vec4f(rgb, col.a);
        pane_depth = 1.0;
    }
    // The two nearest loose shards: depth along the ray, color, coverage.
    var t1 = 1e9;
    var t2 = 1e9;
    var c1 = vec4f(0.0);
    var c2 = vec4f(0.0);
    var a1 = 0.0;
    var a2 = 0.0;
    var shadow = 0.0;
    // The loose shards, searched in the cells around and above the pixel since they fall.
    let look = a - 0.06 * progress * (a - imp) / rch - (a - eye.xy) * 0.06 * progress;
    let g0 = floor(look / s) - 1.0;
    let rows = ceil(1.0 / s);
    for (var ri = 0; ri < 11; ri++) {
        let j = g0.y + f32(ri);
        if (j > rows) { break; }
        if (j < -1.0) { continue; }
        for (var ci = 0; ci < 3; ci++) {
            let c = vec2f(g0.x + f32(ci), j);
            let ca = corner(c);
            let cb = corner(c + vec2f(1.0, 0.0));
            let ccc = corner(c + 1.0);
            let cd = corner(c + vec2f(0.0, 1.0));
            let up = diagonal_up(c);
            for (var k = 0; k < 2; k++) {
                let p0 = select(ca, cb, k == 1 && !up);
                let p1 = select(ccc, cb, k == 0);
                let p2 = select(cd, ccc, k == 0 && up);
                let mid = (p0 + p1 + p2) / 3.0;
                let h1 = hash32(c + vec2f(0.31, 0.57) * f32(k + 1) + seed_offset());
                let away = mid - imp;
                let dist = length(away);
                let dn = clamp(dist / rch, 0.0, 1.0);
                let e = progress - release_time(mid, dn, h1.x, g, margin);
                if (e <= 0.0) { continue; }
                let h2 = hash32(c + vec2f(0.73, 0.19) * f32(k + 1) + seed_offset());
                let near = 1.0 - dn;
                let vel = vec3f(away / max(dist, 1e-3) * (0.03 + 0.08 * h1.y) * (0.4 + near), -(0.05 + 0.2 * near * h1.z));
                let pos = vec3f(mid, 0.0) + vel * e - vec3f(0.0, 0.5 * g * e * e, 0.0);
                if (pos.y + 1.5 * s < -0.05) { continue; }
                let axis = normalize(vec3f(h2.x - 0.5, h2.y - 0.5, 0.3 * (h2.z - 0.5)) + 1e-4);
                let angle = (3.0 + 5.0 * h2.z) * select(1.0, -1.0, h2.x < 0.5) * e;
                let n = rotate(vec3f(0.0, 0.0, -1.0), axis, angle);
                let rel = smoothstep(0.0, 0.04, e);
                let den = dot(ray, n);
                let t = dot(pos - eye, n) / select(1e-4, den, abs(den) > 1e-4);
                let q = mid + rotate(eye + t * ray - pos, axis, -angle).xy;
                let border = min(min(q.x, ratio - q.x), min(q.y, 1.0 - q.y));
                let inside = triangle_dist(q, p0, p1, p2);
                let ed = min(inside, border);
                if (t > 0.0 && t < t2 && t < pane_depth && ed > 0.0) {
                    let nf = select(n, -n, den > 0.0);
                    var col = from_color(vec2f(q.x / ratio, q.y));
                    var rgb = col.rgb * mix(1.0, clamp(dot(nf, light) / -light.z, 0.45, 1.1), rel);
                    let glint = max(dot(nf, halfway), 0.0);
                    rgb += rel * 0.3 * pow(glint, 60.0) * col.a;
                    let line = 0.85 * (1.0 - smoothstep(0.0, CRACK_WIDTH, inside)) * (1.0 - rel);
                    let bevel = 0.8 * rel * (1.0 - smoothstep(0.0, BEVEL, ed)) * (0.3 + 0.7 * pow(glint, 6.0));
                    rgb = mix(rgb, vec3f(0.92, 0.97, 0.97) * col.a, max(line, bevel));
                    col = vec4f(rgb, col.a);
                    let cover = mix(1.0, smoothstep(0.0, 2.0 * EDGE, ed), rel);
                    if (t < t1) {
                        t2 = t1; c2 = c1; a2 = a1;
                        t1 = t; c1 = col; a1 = cover;
                    } else {
                        t2 = t; c2 = col; a2 = cover;
                    }
                }
                let lden = dot(light, n);
                let ts = dot(pos - vec3f(a, 0.0), n) / select(1e-4, lden, abs(lden) > 1e-4);
                let qs = mid + rotate(vec3f(a, 0.0) + ts * light - pos, axis, -angle).xy;
                let eds = min(triangle_dist(qs, p0, p1, p2), min(min(qs.x, ratio - qs.x), min(qs.y, 1.0 - qs.y)));
                if (ts > 0.0 && eds > 0.0) {
                    shadow = max(shadow, rel * smoothstep(0.0, 0.004 + 0.08 * ts, eds) * 0.45 * (1.0 - smoothstep(0.1, 0.9, ts)));
                }
            }
        }
    }
    // The second clip behind, then the pane still in place, then the loose shards in front.
    var back = to_color(uv);
    back = vec4f(back.rgb * (1.0 - shadow), back.a);
    pane = vec4f(pane.rgb * (1.0 - shadow), pane.a);
    if (pane_depth == 1.0) { back = pane; }
    var color = c1 * a1 + c2 * min(a2, 1.0 - a1) + back * max(1.0 - a1 - a2, 0.0);
    let f = sin(3.141592653589793 * clamp(progress / 0.12, 0.0, 1.0));
    let dd = a - imp;
    let flash = 0.6 * f * exp(-dot(dd, dd) / (0.004 + 0.02 * progress));
    return vec4f(color.rgb + flash * color.a, color.a);
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
