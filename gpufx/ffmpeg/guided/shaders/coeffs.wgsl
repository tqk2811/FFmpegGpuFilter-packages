// Guided filter (FFmpeg vf_guided.c), coefficient passes. They run on the subsampled grid (every
// `sub`-th pixel in fast mode, every pixel in basic mode): box means over that grid, with the edge
// samples repeated and a fixed count, of I (first input), P (the guide, or I without one), I * I
// and I * P give out = A * I + B with A = cov(I, P) / (var(I) + eps) and B = mean(P) - A * mean(I).
// The 32-bit floats are stored over the 4 channels of RGBA8 textures, one texture per channel.
fn pk(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}
fn sub_step() -> i32 { return select(1, params.sub, params.mode == 1); }
// FFmpeg's radius on the subsampled grid.
fn sub_radius() -> i32 {
    let n = sub_step();
    if (n == 1) { return params.radius; }
    if (params.radius >= n) { return params.radius / n; }
    return 1;
}
// Grid points: the intermediate textures keep the frame's size, only this corner is used.
fn grid() -> vec2i {
    let n = sub_step();
    return (vec2i(gpufx_input_size(0u)) + n - 1) / n;
}
// A and B of the R, G and B channels at grid point p.
fn coeffs(p: vec2i) -> array<vec3f, 2> {
    let n = sub_step();
    let g = grid();
    let r = sub_radius();
    let guided = gpufx_input_count() > 1u;
    var si = vec3f(0.0);
    var sii = vec3f(0.0);
    var sp = vec3f(0.0);
    var sip = vec3f(0.0);
    for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
            let q = clamp(p + vec2i(dx, dy), vec2i(0), g - 1) * n;
            let i = gpufx_input_load(0u, q).rgb * 255.0;
            var pp = i;
            if (guided) { pp = gpufx_input_load(1u, q).rgb * 255.0; }
            // FFmpeg divides 8-bit codes by 255.
            let fi = i / 255.0;
            let fp = pp / 255.0;
            si += fi;
            sii += fi * fi;
            sp += fp;
            sip += fi * fp;
        }
    }
    let w = f32(2 * r + 1);
    let np = w * w;
    let mi = si / np;
    let mii = sii / np;
    let mp = sp / np;
    let mip = sip / np;
    let a = (mip - mi * mp) / (mii - mi * mi + params.eps);
    let b = mp - a * mi;
    return array<vec3f, 2>(a, b);
}

@compute @workgroup_size(8, 8)
fn coef_a(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || any(vec2i(id.xy) >= grid())) { return; }
    let a = coeffs(vec2i(id.xy))[0];
    gpufx_write(id, pk(a.r));
    gpufx_write1(id, pk(a.g));
    gpufx_write2(id, pk(a.b));
}

@compute @workgroup_size(8, 8)
fn coef_b(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id) || any(vec2i(id.xy) >= grid())) { return; }
    let b = coeffs(vec2i(id.xy))[1];
    gpufx_write(id, pk(b.r));
    gpufx_write1(id, pk(b.g));
    gpufx_write2(id, pk(b.b));
}
