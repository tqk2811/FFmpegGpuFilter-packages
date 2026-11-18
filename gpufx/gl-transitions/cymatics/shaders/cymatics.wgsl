// Port of Cymatics.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Cymatics.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;
const GRAINS: f32 = 140.0;

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let mode_x = params.mode_x;
    let mode_y = params.mode_y;
    let line_width = params.line_width;
    let t = progress;
    // A square plate on the short side keeps the figure symmetric at any aspect ratio.
    let side = min(ratio, 1.0);
    let to_plate = vec2f(ratio, 1.0) / side;
    let p = (uv - 0.5) * to_plate + 0.5;

    let n = mode_x * PI;
    let m = mode_y * PI;
    // Equal modes would cancel out to f = 0 everywhere: close modes switch to the sum, a plain grid of lines.
    let c = 1.0 - 2.0 * smoothstep(0.0, 1.0, abs(mode_x - mode_y));
    let cn = cos(n * p);
    let cm = cos(m * p);
    let sn = sin(n * p);
    let sm = sin(m * p);
    let f = cn.x * cm.y + c * cm.x * cn.y;
    let g = -vec2f(n * sn.x * cm.y + c * m * sm.x * cn.y, m * cn.x * sm.y + c * n * cm.x * sn.y);
    let gl2 = max(dot(g, g), 1e-3);

    // Sand covers |f| < w; |f| <= 2, so w = 3.2 covers the whole plate with the grainy edge.
    let x = clamp(t / 0.55, 0.0, 1.0);
    let gather = x * (1.6 - 0.6 * x);
    let w = mix(3.2, line_width, gather) * (1.0 - smoothstep(0.5, 0.97, t));
    let shake = smoothstep(0.0, 0.08, t) * (1.0 - 0.6 * smoothstep(0.4, 0.75, t));

    let gid = floor(uv * vec2f(ratio, 1.0) * GRAINS);
    let r1 = hash12(gid);
    let r2 = hash12(gid + 17.3);
    let r3 = hash12(gid + 41.7);

    // The sand here came from the level f * k: one Newton step along the gradient, softly limited
    // where the plate is nearly flat; k stops growing once the lines have formed.
    let k = 3.2 / max(w, line_width);
    var d = g / gl2 * (clamp(f * k, -2.0, 2.0) - f);
    d *= smoothstep(0.0, 0.1, t) / (1.0 + length(d) / 0.1);
    let jit = (vec2f(r1, r2) - 0.5) * 0.004 * shake * sin(t * 48.0 + r1 * 6.28);
    let sand0 = from_color(mirror(uv + (d + jit) / to_plate));

    // Evens out the line width where the plate barely moves, relative to its typical slope.
    let gn = sqrt(gl2);
    let even = mix(1.0, clamp(gn / (2.06 * length(vec2f(mode_x, mode_y))), 0.45, 1.6), gather);
    let s = abs(f) / max(w * even, 1e-4);
    // The pile -(f / w)^2 lit from the top left, its slope taken relative to the line width.
    let lit = dot(min(s, 1.2) * sign(f) * g / gn, vec2f(-0.7071, 0.7071)) * 0.3;
    let relief = smoothstep(0.08, 0.4, t);
    let sand = vec4f(sand0.rgb * (1.0 + shake * (r1 - 0.5) * 0.14 + relief * lit), sand0.a);

    let hop = smoothstep(0.6, 0.97, t);
    let thr = 0.72 + 0.4 * r2;
    let a = (1.0 - smoothstep(thr - 0.06, thr + 0.06, s)) * step(hop, r3 * 0.9 + 0.05);

    let plate0 = to_color(uv);
    let sh = (1.0 - smoothstep(1.0, 1.7, s)) * 0.3 * gather * (1.0 - hop);
    let plate = vec4f(plate0.rgb * (1.0 - sh), plate0.a);
    return mix(plate, sand, a);
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
