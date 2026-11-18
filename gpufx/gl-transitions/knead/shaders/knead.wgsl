// Port of Knead.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Knead.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const SWAP: f32 = 1.2;

fn img(q: vec2f, incoming: bool) -> vec4f {
    if (incoming) { return to_color(q); }
    return from_color(q);
}

// Undoes n complete kneads: the bottom row came from the left half, the top row from the right half.
fn unknead(q0: vec2f, n: i32) -> vec2f {
    var q = q0;
    for (var i = 0; i < 5; i++) {
        if (i >= n) { break; }
        q = select(vec2f(0.5 + 0.5 * q.x, 2.0 * q.y - 1.0), vec2f(0.5 * q.x, 2.0 * q.y), q.y < 0.5);
    }
    return q;
}

// Unknead of (row + t) / 2^n, with the row taken from its bits so t = 1 stays in that row.
fn unknead_row(x0: f32, row0: f32, t: f32, n: i32) -> vec2f {
    var h = exp2(f32(n));
    var row = row0;
    var x = x0;
    for (var i = 0; i < 5; i++) {
        if (i >= n) { break; }
        h *= 0.5;
        let hi = step(h, row);
        row -= hi * h;
        x = 0.5 * x + 0.5 * hi;
    }
    return vec2f(x, t);
}

fn box(p: vec2f, lo: vec2f, hi: vec2f, soft: vec2f) -> f32 {
    let d = min(p - lo, hi - p) / soft;
    return clamp(min(d.x, d.y), 0.0, 1.0);
}

// Rounded layer lit from above; equal at t = 0 and 1 so stacked layers meet without a seam.
fn layer_shade(t: f32, amount: f32) -> f32 {
    let c = 2.0 * t - 1.0;
    let c2 = c * c;
    return 1.0 + amount * (0.25 * c * (1.0 - c2) - 0.55 * c2 * c2);
}

fn creases(y: f32, rows: f32, amount: f32) -> f32 {
    return layer_shade(fract(y * rows), amount);
}

// n complete kneads, then the next one at stage s; g fades the layer shading in and out over the transition.
fn kneaded(uv: vec2f, n: i32, s: f32, incoming: bool, g: f32, ratio: f32) -> vec4f {
    let shadow = params.shadow;
    let env = 4.0 * s * (1.0 - s);
    let rows = exp2(f32(n));
    let amount = shadow * g;
    // Widening leads squashing so the corners they uncover stay small.
    let st = vec2f(smoothstep(0.0, 0.75, s), smoothstep(0.25, 1.0, s));
    // Edges soften only once the halves overlap, so no gap line shows where they meet.
    let soft = vec2f(0.004 / ratio, 0.004) * smoothstep(0.0, 0.3, st.x) * smoothstep(0.0, 0.3, 1.0 - st.y) + 1e-6;
    let hi_l = vec2f(0.5 + 0.5 * st.x, 1.0 - 0.5 * st.y);
    let lo_r = vec2f(0.5 - 0.5 * st.x, 0.5 * st.y);
    let l = uv / hi_l;
    let r = (uv - lo_r) / (1.0 - lo_r);
    let xs = vec2f(0.1 / ratio, 0.1);
    // Shading waits for the halves to separate so no seam shows at the cut.
    let lift = env * smoothstep(0.0, 0.3, st.x);

    var bottom = img(unknead(vec2f(0.5 * l.x, l.y), n), incoming);
    bottom = vec4f(bottom.rgb * creases(l.y, rows, amount) * (1.0 - 0.7 * shadow * lift * (1.0 - smoothstep(0.0, xs.x, hi_l.x - uv.x))), bottom.a);
    var c = mix(params.back_color, bottom, box(uv, vec2f(-1.0), hi_l + soft, soft));

    let off = vec2f(0.02 / ratio, -0.03) * lift;
    let sh = 1.0 - smoothstep(0.0, 0.05, -min(ratio * min(uv.x - off.x - lo_r.x, 1.0 - uv.x + off.x), min(uv.y - off.y - lo_r.y, 1.0 - uv.y + off.y)));
    c = vec4f(c.rgb * (1.0 - shadow * 0.6 * lift * sh), c.a);

    var top = img(unknead(vec2f(0.5 + 0.5 * r.x, r.y), n), incoming);
    top = vec4f(top.rgb * creases(r.y, rows, amount) * (1.0 + 0.08 * lift) * (1.0 - 0.7 * shadow * lift * (1.0 - smoothstep(0.0, xs.x, uv.x - lo_r.x))), top.a);
    return mix(c, top, box(uv, lo_r, vec2f(2.0), soft));
}

// Layers of the second clip pressed in under each layer of the first, from alternate sides, until they fill the rows.
fn interleave(uv: vec2f, n: i32, w: f32, g: f32) -> vec4f {
    let shadow = params.shadow;
    let rows = exp2(f32(n));
    let amount = shadow * g;
    let y = uv.y * rows;
    let row = floor(y);
    let t = y - row;
    let side = select(1.0 - uv.x, uv.x, row - 2.0 * floor(row / 2.0) < 1.0);
    let f = smoothstep(0.0, 1.0, clamp(1.7 * w - 0.7 * side, 0.0, 1.0));
    let t_in = clamp(t / max(f, 1e-4), 0.0, 1.0);
    let t_out = clamp((t - f) / max(1.0 - f, 1e-4), 0.0, 1.0);
    let a0 = to_color(unknead_row(uv.x, row, t_in, n));
    let b0 = from_color(unknead_row(uv.x, row, t_out, n));
    // Squeezed layers get darker toward their tip, as they thin out.
    let a = vec4f(a0.rgb * layer_shade(t_in, amount) * (1.0 - 0.4 * shadow * (1.0 - smoothstep(0.0, 0.5, f))), a0.a);
    let b = vec4f(b0.rgb * layer_shade(t_out, amount) * (1.0 - 0.4 * shadow * (1.0 - smoothstep(0.0, 0.5, 1.0 - f))), b0.a);
    // The shift keeps row boundaries on the full layer when the other one is empty.
    let edge = 0.0015 * min(1.0, 8.0 * f * (1.0 - f)) + 1e-6;
    return mix(a, b, smoothstep(-edge, edge, (t - f) / rows + edge * (1.0 - 2.0 * f)));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let kn = i32(clamp(f32(params.kneads), 1.0, 5.0));
    let n = f32(kn);
    let g = smoothstep(0.0, 0.12, progress) * smoothstep(0.0, 0.12, 1.0 - progress);
    let u = progress * (2.0 * n + SWAP);
    if (u < n) {
        let k = floor(u);
        return kneaded(uv, i32(k), smoothstep(0.0, 1.0, u - k), false, g, ratio);
    }
    let v = 2.0 * n + SWAP - u;
    if (v < n) {
        let k = floor(v);
        return kneaded(uv, i32(k), smoothstep(0.0, 1.0, v - k), true, g, ratio);
    }
    return interleave(uv, kn, (u - n) / SWAP, g);
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
