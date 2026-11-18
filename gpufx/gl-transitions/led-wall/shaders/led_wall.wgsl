// Port of LedWall.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LedWall.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const RADIUS: f32 = 0.36;
const EDGE: f32 = 0.05;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn mirrored(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return mix(m, 2.0 - m, step(vec2f(1.0), m));
}

fn disc(d: f32, r: f32) -> f32 {
    return 1.0 - smoothstep(r - EDGE, r + EDGE, d);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let glow = params.glow;
    let flash = params.flash;
    let panel = params.panel;
    let led = smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
    let z = 1.0 + max(params.zoom, 0.0) * smoothstep(0.0, 0.45, progress) * (1.0 - smoothstep(0.55, 1.0, progress));
    let p = 0.5 + (uv - 0.5) / z;

    let aspect = vec2f(ratio, 1.0);
    let to_cells = aspect * max(params.cells, 1.0) / min(ratio, 1.0);
    let q = (p - 0.5) * to_cells;
    let id = floor(q + 0.5);
    let local = q - id;
    let side = vec2f(select(1.0, -1.0, local.x < 0.0), select(1.0, -1.0, local.y < 0.0));

    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 1e-4) { dir = normalize(params.direction); }
    let extent = abs(dir.x) * ratio + abs(dir.y);

    var own = vec4f(0.0);
    var own_switch = 0.0;
    var halo = vec4f(0.0);
    var halo_weight = 0.0;
    // This diode and the three nearest ones, whose glow reaches this point.
    for (var i = 0; i < 4; i++) {
        if (i > 0 && glow * led <= 0.0) { break; }
        let fi = f32(i);
        let o = vec2f(fi - 2.0 * floor(fi / 2.0), floor(fi / 2.0)) * side;
        let c = id + o;
        let cuv = c / to_cells + 0.5;
        // Where the diode is seen in the frame, so that the wave crosses the visible screen.
        let s = clamp(dot((cuv - 0.5) * z * aspect, dir) / extent + 0.5, 0.0, 1.0);
        let when = 0.2 + 0.52 * s + 0.05 * (hash12(c + 71.0) - 0.5);
        let sw = smoothstep(when - 0.012, when + 0.012, progress);
        let x = (progress - when) / 0.018;
        let pop = exp(-x * x) - 0.5 * exp(-(x + 1.6) * (x + 1.6));
        let suv = mirrored(cuv);
        var col = mix(from_color(suv), to_color(suv), sw);
        col = vec4f(col.rgb * (1.0 + 1.4 * flash * pop) + 0.2 * flash * max(pop, 0.0), col.a);
        if (i == 0) {
            own = col;
            own_switch = sw;
        }
        let d = length(local - o);
        var w = 0.9 * glow * exp(-6.0 * max(d - RADIUS, 0.0)) * (1.0 + 0.8 * flash * max(pop, 0.0));
        // The neighbors fade out where the next ones take over, so the glow has no seam.
        if (o.x != 0.0) { w *= smoothstep(0.0, 0.2, abs(local.x)); }
        if (o.y != 0.0) { w *= smoothstep(0.0, 0.2, abs(local.y)); }
        halo += w * col;
        halo_weight += w;
    }

    let plain = mix(from_color(p), to_color(p), own_switch);
    let d = length(local);
    // The diodes cover their whole cell with the plain picture when led = 0: the dark panel
    // shows up first between them, then they light up with the color of their center.
    var r = mix(0.8, RADIUS, smoothstep(0.0, 0.6, led));
    var gap = vec4f(panel.rgb, panel.a * own.a);
    if (halo_weight > 0.0) {
        gap = mix(gap, halo / halo_weight, clamp(halo_weight * led, 0.0, 1.0));
    }
    var body = own;
    if (params.triads != 0u) {
        let sub = vec3f(
            disc(length(local - vec2f(0.0, 0.15)), 0.2),
            disc(length(local - vec2f(-0.13, -0.075)), 0.2),
            disc(length(local - vec2f(0.13, -0.075)), 0.2));
        let m = max(sub.r, max(sub.g, sub.b));
        body = vec4f(gap.rgb * (1.0 - m) + own.rgb * 1.5 * sub, mix(gap.a, own.a, m));
        r = max(r, 0.45);
    } else {
        let k = clamp(d / RADIUS, 0.0, 1.0);
        body = vec4f(body.rgb * (0.8 + 0.45 * (1.0 - k * k)), body.a);
    }
    let lit = smoothstep(0.0, 0.8, led);
    body = mix(plain, body, lit * mix(1.0, lit, smoothstep(0.0, 0.7, d)));
    let color = mix(gap, body, disc(d, r));
    return clamp(color, vec4f(0.0), vec4f(1.0));
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
