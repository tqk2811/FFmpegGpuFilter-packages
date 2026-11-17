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
    let s = vec2i(textureDimensions(sr));
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

// Bayes: total of the row sums of each sub-band, in the texel (sub-band, 0).
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    var acc = vec3f(0.0);
    if (id.y == 0u && params.threshold_type == 1) {
        let h = i32(textureDimensions(sr).y);
        for (var y = 0; y < h; y++) {
            let p = vec2i(i32(id.x), y);
            acc += vec3f(up(textureLoad(sr, p, 0)), up(textureLoad(sg, p, 0)), up(textureLoad(sb, p, 0)));
        }
    }
    gpufx_write(id, pk(acc.r));
    gpufx_write1(id, pk(acc.g));
    gpufx_write2(id, pk(acc.b));
}
