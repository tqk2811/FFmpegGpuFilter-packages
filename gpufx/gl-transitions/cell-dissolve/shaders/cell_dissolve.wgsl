// Port of CellDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CellDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.0015;

fn hash22(p: vec2f) -> vec2f {
    var p3 = fract(vec3f(p.x, p.y, p.x) * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let a = from_color(uv);
    let b = to_color(uv);

    let n = max(params.cells, 1.0);
    // Measured in square pixels, so the cells are not stretched.
    let p = uv * vec2f(ratio, 1.0) * n;
    let i = floor(p);
    let f = p - i;
    let offset = vec2f(17.31, 41.97) * params.seed;

    var mg = vec2f(0.0);
    var mr = vec2f(0.0);
    var md = 8.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let g = vec2f(f32(x), f32(y));
            let r = g + hash22(i + g + offset) - f;
            let d = dot(r, r);
            if (d < md) {
                md = d;
                mr = r;
                mg = g;
            }
        }
    }

    // Distance to the nearest cell edge: the bisector with the closest neighbor point, searched
    // over 5x5 cells around the nearest one so that no edge is missed.
    var edge = 8.0;
    for (var y = -2; y <= 2; y++) {
        for (var x = -2; x <= 2; x++) {
            let g = mg + vec2f(f32(x), f32(y));
            let r = g + hash22(i + g + offset) - f;
            let dr = r - mr;
            if (dot(dr, dr) > 0.00001) {
                edge = min(edge, dot(0.5 * (mr + r), normalize(dr)));
            }
        }
    }
    edge /= n;

    let h = hash22(i + mg + offset + 97.13).x;
    let w = clamp(params.smoothness, 0.0, 1.0);
    let start = h * (1.0 - w);
    var m = step(start, progress);
    if (w > 0.0) { m = smoothstep(start, start + w, progress); }

    // Mixed premultiplied, so transparent clips do not bleed their color.
    var c = mix(vec4f(a.rgb * a.a, a.a), vec4f(b.rgb * b.a, b.a), m);

    let open = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    let bw = max(params.border, 0.0) * open;
    if (bw > 0.0) {
        let l = 1.0 - smoothstep(0.5 * bw - AA, 0.5 * bw + AA, edge);
        let ba = params.border_color.a * l * min(1.0, bw / (2.0 * AA));
        c = vec4f(params.border_color.rgb * ba, ba) + c * (1.0 - ba);
    }
    if (c.a > 0.0) { return vec4f(c.rgb / c.a, c.a); }
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
