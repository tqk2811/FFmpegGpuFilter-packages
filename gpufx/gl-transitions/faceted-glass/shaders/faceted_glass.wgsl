// Port of FacetedGlass.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FacetedGlass.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;

fn hash22(p: vec2f) -> vec2f {
    var p3 = fract(vec3f(p.xyx) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

fn mirror(v: vec2f) -> vec2f {
    let m = v - 2.0 * floor(v / 2.0);
    return 1.0 - abs(1.0 - m);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let hp = 1.0 - abs(2.0 * progress - 1.0);
    let amount = hp * hp * (3.0 - 2.0 * hp);

    let n = max(params.facets, 1.0);
    let aspect = vec2f(globals.size.x / globals.size.y, 1.0);
    // Measured in square pixels, so the facets are not stretched.
    let p = uv * aspect * n;
    let i = floor(p);
    let f = p - i;
    let offset = vec2f(17.31, 41.97) * params.seed;
    let bw = 0.18 * amount;

    var mg = vec2f(0.0);
    var mr = vec2f(0.0);
    var md = 8.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let g = vec2f(f32(x), f32(y));
            let r = g + 0.1 + 0.8 * hash22(i + g + offset) - f;
            let d = dot(r, r);
            if (d < md) {
                md = d;
                mr = r;
                mg = g;
            }
        }
    }

    // Distance to the nearest facet edge, and the direction toward the edges, blended
    // between neighboring edges near the corners so the bevel lighting turns smoothly.
    var edge = 8.0;
    var normal = vec2f(0.0);
    for (var y = -2; y <= 2; y++) {
        for (var x = -2; x <= 2; x++) {
            let g = mg + vec2f(f32(x), f32(y));
            let r = g + 0.1 + 0.8 * hash22(i + g + offset) - f;
            let dr = r - mr;
            if (dot(dr, dr) > 0.00001) {
                let dn = normalize(dr);
                let e = dot(0.5 * (mr + r), dn);
                edge = min(edge, e);
                let w = max(1.0 - e / max(bw, 1e-6), 0.0);
                normal += dn * w * w;
            }
        }
    }
    let nl = length(normal);
    normal = select(vec2f(0.0), normal / max(nl, 1e-9), nl > 0.0);

    let id = i + mg + offset;
    let h1 = hash22(id + 31.7);
    let h2 = hash22(id + 59.3);
    let h3 = hash22(id + 97.1);
    let angle = 6.2831853 * h1.x;
    let dir = vec2f(cos(angle), sin(angle));
    let shift = dir * (0.4 + 0.6 * h1.y) * params.refraction;
    let zoom = (h2.x - 0.5) * 6.0 * params.refraction;
    let tilt = (h2.y - 0.5) * 2.0 * params.refraction;

    let q = -mr / n;
    let view = -q * zoom + vec2f(-q.y, q.x) * sin(tilt) + q * (cos(tilt) - 1.0);

    var bv = 1.0 - smoothstep(0.0, bw, edge);
    bv *= bv;
    let bend = normal * bv * 0.4 * params.refraction;

    let start = 0.15 + 0.5 * h3.x;
    let m = smoothstep(start, start + 0.2, progress);
    let d = amount * (view + bend);
    let s = amount * shift;
    let ca = from_color(mirror(uv + (s + d) / aspect));
    let cb = to_color(mirror(uv + (d - s) / aspect));
    // Mixed premultiplied, so transparent clips do not bleed their color.
    var c = mix(vec4f(ca.rgb * ca.a, ca.a), vec4f(cb.rgb * cb.a, cb.a), m);

    let light = normalize(vec2f(-0.6, 0.8));
    let slope = dir * (0.4 + 0.6 * h1.y);
    let facet_light = 0.12 * amount * dot(slope, light);
    let lit = dot(normal, light);
    let k = clamp(params.bevel, 0.0, 1.0);
    var glow = k * bv * max(lit, 0.0) * 1.1 * amount;
    let shade = k * bv * max(-lit, 0.0) * 0.6 * amount;
    let turn = sin(3.14159265 * m);
    glow += k * 0.15 * amount * turn * turn;
    let seam = 0.6 * amount * (1.0 - smoothstep(0.0, 2.0 * AA, edge / n - 0.5 * AA));

    let hl = params.highlight;
    let rgb = c.rgb * (1.0 + facet_light) * (1.0 - shade) * (1.0 - seam) + hl.rgb * hl.a * glow * c.a;
    return select(vec4f(0.0), vec4f(clamp(rgb / max(c.a, 1e-6), vec3f(0.0), vec3f(1.0)), c.a), c.a > 0.0);
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
