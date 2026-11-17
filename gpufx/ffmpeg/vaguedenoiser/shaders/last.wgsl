// Helpers shared by the vaguedenoiser passes (FFmpeg vf_vaguedenoiser.c). The wavelet
// coefficients of the R, G and B channels are f32 values stored as their 32 bits over the
// four 8-bit channels of a texel, one texture per channel.
fn pk(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}
fn up(t: vec4f) -> f32 {
    let b = vec4u(round(t * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}
// Number of steps: the param, at most FFmpeg's cap from the picture size.
fn steps() -> i32 {
    let s = vec2i(textureDimensions(ar));
    var m = 1;
    for (; m < 15; m++) {
        if ((1 << u32(m)) >= s.x || (1 << u32(m)) >= s.y) { break; }
    }
    return max(min(params.nsteps, m - 2), 0);
}
// Size of the region the transform works on at level k: (n + 1) >> 1, k times.
fn lsize(n: i32, k: i32) -> i32 {
    var v = n;
    for (var i = 0; i < k; i++) { v = (v + 1) >> 1; }
    return v;
}
// Whole-sample symmetric extension ... 2 1 0 | 0 1 2 ... of index m into [0, n).
fn mirror(m: i32, n: i32) -> i32 {
    if (n <= 1) { return 0; }
    let p = 2 * n - 2;
    var v = abs(m) % p;
    if (v >= n) { v = p - v; }
    return v;
}
// FFmpeg's extension of the low half (left whole-sample, right half-sample for even sizes).
fn ext_low(k: i32, n: i32) -> i32 {
    let ls = (n + 1) >> 1;
    var v = k;
    if (v < 0) { v = -v; }
    if (v > ls - 1) { v = select(2 * (ls - 1) - v, 2 * ls - 1 - v, n % 2 == 0); }
    return clamp(v, 0, ls - 1);
}
// FFmpeg's extension of the high half (left half-sample, right whole-sample for even sizes).
fn ext_high(j: i32, n: i32) -> i32 {
    let hs = n >> 1;
    var v = j;
    if (v < 0) { v = -1 - v; }
    if (v > hs - 1) { v = select(2 * hs - 1 - v, 2 * (hs - 1) - v, n % 2 == 0); }
    return clamp(v, 0, max(hs - 1, 0));
}
const AL = array<f32, 5>(0.852698679009403, 0.377402855612654, -0.110624404418423, -0.023849465019380, 0.037828455506995);
const AH = array<f32, 4>(-0.788485616405664, 0.418092273222212, 0.040689417609558, -0.064538882628938);
const SL = array<f32, 4>(0.788485616405664, 0.418092273222212, -0.040689417609558, -0.064538882628938);
const SH = array<f32, 5>(-0.852698679009403, 0.377402855612654, 0.110624404418423, -0.023849465019380, -0.037828455506995);
// Analysis of sample i (of the n along the line, after the low/high split) of a line read by f(m).
fn ld(p: vec2i) -> vec3f {
    return vec3f(up(textureLoad(ar, p, 0)), up(textureLoad(ag, p, 0)), up(textureLoad(ab, p, 0)));
}
fn inv(c: vec2i, k: i32, horiz: bool) -> vec3f {
    let s = vec2i(textureDimensions(ar));
    let lh = lsize(s.x, k);
    let lv = lsize(s.y, k);
    if (k >= steps() || c.x >= lh || c.y >= lv) { return ld(c); }
    let ax = select(vec2i(0, 1), vec2i(1, 0), horiz);
    let n = select(lv, lh, horiz);
    let y = select(c.y, c.x, horiz);
    let base = c - ax * y;
    let ls = (n + 1) >> 1;
    var acc = vec3f(0.0);
    for (var d = -2; d <= 2; d++) {
        let kk = (y >> 1) + d;
        let m = abs(y - 2 * kk);
        if (m <= 3) { acc += SL[m] * ld(base + ax * ext_low(kk, n)); }
    }
    for (var d = -2; d <= 2; d++) {
        let j = ((y - 1) >> 1) + d;
        let m = abs(y - 2 * j - 1);
        if (m <= 4) { acc += SH[m] * ld(base + ax * (ls + ext_high(j, n))); }
    }
    return acc;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let c = vec2i(id.xy);
    let px = textureLoad(src, c, 0);
    let v = inv(c, 0, true);
    // FFmpeg's planes bits on gbrp: 1 G, 2 B, 4 R.
    let on = vec3<bool>((params.planes & 4) != 0, (params.planes & 1) != 0, (params.planes & 2) != 0);
    let o = select(px.rgb, clamp(trunc(v + 0.5), vec3f(0.0), vec3f(255.0)) / 255.0, on);
    gpufx_write(id, vec4f(o, px.a));
}
