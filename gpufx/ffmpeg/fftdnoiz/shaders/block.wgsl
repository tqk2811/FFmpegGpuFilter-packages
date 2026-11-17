// FFT block denoiser (FFmpeg vf_fftdnoiz.c, spatial part only) on one channel per pass.
// One workgroup takes a block at a time: the windowed block is turned into its 2-D spectrum
// (rows, then columns), each frequency is scaled down from its power, and the inverse
// transform gives back the middle `size` x `size` pixels of the block, divided by the window.
// The blocks step by `size`, so each pixel comes from exactly one block, as in FFmpeg.
//
// The spectrum of a real block is conjugate-symmetric, so only the columns u <= b / 2 are kept:
// b floats per row (u = 0 and, for an even b, u = b / 2 are real). b <= 64 keeps it within the
// 16 KiB of workgroup storage WebGPU guarantees.
const MAXB = 64;
const TAU = 6.283185307179586;
var<workgroup> spec: array<f32, 4096>;

// FFmpeg's window functions (window_func.h), N = b + 1 points.
fn bessel_i0(x: f32) -> f32 {
    var sum = 1.0;
    var term = 1.0;
    let q = x * x * 0.25;
    for (var k = 1; k < 60; k++) {
        term *= q / f32(k * k);
        sum += term;
        if (term < sum * 1e-8) { break; }
    }
    return sum;
}
fn lut(n: i32, bn: i32) -> f32 {
    let N = bn + 1;
    let m = f32(N - 1);
    let fn_ = f32(n);
    let c1 = cos(TAU * fn_ / m);
    let c2 = cos(2.0 * TAU * fn_ / m);
    let c3 = cos(3.0 * TAU * fn_ / m);
    let x = 2.0 * (fn_ / m - 0.5);
    switch (params.window) {
        case 0: { return 1.0; }
        case 1: { return 1.0 - abs((fn_ - m / 2.0) / (m / 2.0)); }
        case 2, 3: { return 0.5 * (1.0 - c1); }
        case 4: { return 0.54 - 0.46 * c1; }
        case 5: { return 0.42659 - 0.49656 * c1 + 0.076849 * c2; }
        case 6: { let t = (fn_ - m / 2.0) / (m / 2.0); return 1.0 - t * t; }
        case 7: {
            var s = 1.0;
            let k = array<f32, 10>(-1.985844164102, 1.791176438506, -1.282075284005, 0.667777530266, -0.240160796576,
                                   0.056656381764, -0.008134974479, 0.000624544650, -0.000019808998, 0.000000132974);
            for (var i = 0; i < 10; i++) { s += k[i] * cos(f32(i + 1) * TAU * fn_ / m); }
            return s;
        }
        case 8: { return 0.35875 - 0.48829 * c1 + 0.14128 * c2 - 0.01168 * c3; }
        case 9: { return 0.3635819 - 0.4891775 * c1 + 0.1365995 * c2 - 0.0106411 * c3; }
        case 10: { return 0.62 - 0.48 * abs(fn_ / m - 0.5) - 0.38 * c1; }
        case 11: { return sin(TAU * 0.5 * fn_ / m); }
        case 12: { return 0.355768 - 0.487396 * c1 + 0.144232 * c2 - 0.012604 * c3; }
        case 13: {
            let t = 2.0 * fn_ / m - 1.0;
            if (t == 0.0) { return 1.0; }
            return sin(TAU * 0.5 * t) / (TAU * 0.5 * t);
        }
        case 14: {
            // FFmpeg divides (N - 1) / 2 as integers here.
            let t = f32(n - (N - 1) / 2) / (0.4 * m / 2.0);
            return exp(-0.5 * t * t);
        }
        case 15: {
            let M = m / 2.0;
            let d = abs(fn_ - M);
            if (d >= 0.3 * M) { return 0.5 * (1.0 + cos(TAU * 0.5 * (d - 0.3 * M) / ((1.0 - 0.3) * M))); }
            return 1.0;
        }
        case 16: {
            if (x <= -0.5 || x >= 0.5) { return 0.0; }
            return min(1.0, abs(1.0 / (1.0 + 64.0 * x * x)));
        }
        case 17: {
            if (x > 0.25 && x <= 0.5) { let t = 2.0 * x - 1.0; return -2.0 * t * t * t; }
            if (x >= -0.5 && x < -0.25) { let t = 1.0 + 2.0 * x; return 2.0 * t * t * t; }
            if (x >= -0.25 && x < 0.0) { return 1.0 - 24.0 * x * x - 48.0 * x * x * x; }
            if (x >= 0.0 && x <= 0.25) { return 1.0 - 24.0 * x * x + 48.0 * x * x * x; }
            return 0.0;
        }
        case 18: {
            if (x >= 0.0 && x <= 0.5) { return exp(-6.0 * x); }
            if (x < 0.0 && x >= -0.5) { return exp(6.0 * x); }
            return 0.0;
        }
        case 19: {
            let t = abs(2.0 * fn_ / m - 1.0);
            return (1.0 - t) * cos(TAU * 0.5 * t) + sin(TAU * 0.5 * t) / (TAU * 0.5);
        }
        default: {
            let t = fn_ * (2.0 / m) - 1.0;
            return bessel_i0(12.0 * sqrt(max(1.0 - t * t, 0.0))) / bessel_i0(12.0);
        }
    }
}

// e^(i 2 pi k / b) for any integer k.
fn tw(k: i32, b: i32) -> vec2f {
    let a = TAU * f32(((k % b) + b) % b) / f32(b);
    return vec2f(cos(a), sin(a));
}
fn cmul(a: vec2f, b: vec2f) -> vec2f { return vec2f(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }

// Slot of the real part of column u in a row of `spec` (the imaginary part follows when the
// column is complex).
fn slot(u: i32, b: i32) -> i32 {
    if (u == 0) { return 0; }
    if ((b & 1) == 0) {
        if (u == b / 2) { return 1; }
        return 2 * u;
    }
    return 2 * u - 1;
}
fn is_real(u: i32, b: i32) -> bool { return u == 0 || ((b & 1) == 0 && u == b / 2); }

fn chan(v: vec4f, ch: i32) -> f32 {
    return select(select(v.b, v.g, ch == 1), v.r, ch == 0);
}

// Per-invocation tables: the twiddles e^(i 2 pi k / b) and the window points.
var<private> twt: array<vec2f, MAXB>;
var<private> wint: array<f32, 65>;
// Results of the (row, column) pairs a thread computes, kept until the whole workgroup has
// read the old contents of `spec`.
const MAXR = 33;

fn twi(k: i32, b: i32) -> vec2f { return twt[((k % b) + b) % b]; }

fn run(ch: i32, wg: vec3u, nwg: vec3u, lid: u32) {
    let s = vec2i(textureDimensions(src));
    let b = clamp(params.block, 8, MAXB);
    let o = i32(round(f32(b) * params.overlap));
    let hov = o / 2;
    let size = b - o;
    let nox = (s.x + size - 1) / size;
    let noy = (s.y + size - 1) / size;
    let nblocks = nox * noy;
    let scale = 1.0 / f32(b * b);
    let sigma = params.sigma / f32(b * b);
    let limit = 1.0 - params.amount;
    let half = b / 2;
    let nu = half + 1;
    let pairs = b * nu;
    let first = i32(wg.y * nwg.x + wg.x);
    let step = i32(nwg.x * nwg.y);
    let t = i32(lid);
    for (var k = 0; k < b; k++) { twt[k] = tw(k, b); }
    for (var n = 0; n <= b; n++) { wint[n] = lut(n, b); }
    var res: array<vec2f, MAXR>;
    for (var blk = first; blk < nblocks; blk += step) {
        let x0 = (blk % nox) * size;
        let y0 = (blk / nox) * size;
        let rh = min(b, s.y - y0 + hov);
        let rw = min(b, s.x - x0 + hov);
        let rhe = min(size, s.y - y0);
        let rwe = min(size, s.x - x0);
        // The windowed block. Rows and columns past the picture repeat the last ones, window
        // included. FFmpeg mirrors the columns left of the block around its first column (abs
        // of the offset inside the row), not around the picture edge; rows use the picture.
        for (var e = t; e < b * b; e += 64) {
            let ii = min(e / b, rh - 1);
            let jj = min(e % b, rw - 1);
            let p = vec2i(x0 + abs(jj - hov), abs(y0 + ii - hov));
            spec[e] = chan(textureLoad(src, p, 0), ch) * 255.0 * scale * (wint[ii] * wint[jj]);
        }
        workgroupBarrier();
        // Rows: (row i, column u) pairs.
        for (var r = 0; r < MAXR; r++) {
            let e = t + 64 * r;
            if (e >= pairs) { break; }
            let i = e / nu;
            let u = e % nu;
            var acc = vec2f(0.0);
            for (var j = 0; j < b; j++) { acc += spec[i * b + j] * twi(-u * j, b); }
            res[r] = acc;
        }
        workgroupBarrier();
        for (var r = 0; r < MAXR; r++) {
            let e = t + 64 * r;
            if (e >= pairs) { break; }
            let i = e / nu;
            let u = e % nu;
            let k = slot(u, b);
            spec[i * b + k] = res[r].x;
            if (!is_real(u, b)) { spec[i * b + k + 1] = res[r].y; }
        }
        workgroupBarrier();
        // Columns: (frequency v, column u) pairs, scaled from their power. A real column has a
        // conjugate-symmetric spectrum: its v <= b / 2 are kept, packed over the rows like a row.
        for (var r = 0; r < MAXR; r++) {
            let e = t + 64 * r;
            if (e >= pairs) { break; }
            let v = e / nu;
            let u = e % nu;
            let k = slot(u, b);
            let real = is_real(u, b);
            if (real && v > half) { continue; }
            var acc = vec2f(0.0);
            for (var i = 0; i < b; i++) {
                let c = vec2f(spec[i * b + k], select(spec[i * b + k + 1], 0.0, real));
                acc += cmul(c, twi(-v * i, b));
            }
            let power = dot(acc, acc);
            var factor: f32;
            if (params.method == 0) {
                factor = max(limit, (power - sigma) / (power + 1e-15));
            } else {
                factor = select(1.0, limit, power < sigma);
            }
            res[r] = acc * factor;
        }
        workgroupBarrier();
        for (var r = 0; r < MAXR; r++) {
            let e = t + 64 * r;
            if (e >= pairs) { break; }
            let v = e / nu;
            let u = e % nu;
            let k = slot(u, b);
            if (is_real(u, b)) {
                if (v > half) { continue; }
                let sv = slot(v, b);
                spec[sv * b + k] = res[r].x;
                if (!is_real(v, b)) { spec[(sv + 1) * b + k] = res[r].y; }
            } else {
                spec[v * b + k] = res[r].x;
                spec[v * b + k + 1] = res[r].y;
            }
        }
        workgroupBarrier();
        // Inverse columns for the rows kept: (row i, column u) pairs.
        let ipairs = rhe * nu;
        for (var r = 0; r < MAXR; r++) {
            let e = t + 64 * r;
            if (e >= ipairs) { break; }
            let i = e / nu + hov;
            let u = e % nu;
            let k = slot(u, b);
            var acc = vec2f(0.0);
            if (is_real(u, b)) {
                acc.x = spec[k];
                if ((b & 1) == 0) { acc.x += spec[b + k] * select(1.0, -1.0, (i & 1) == 1); }
                for (var v = 1; v < (b + 1) / 2; v++) {
                    let sv = slot(v, b);
                    let w = twi(v * i, b);
                    acc.x += 2.0 * (spec[sv * b + k] * w.x - spec[(sv + 1) * b + k] * w.y);
                }
            } else {
                for (var v = 0; v < b; v++) {
                    acc += cmul(vec2f(spec[v * b + k], spec[v * b + k + 1]), twi(v * i, b));
                }
            }
            res[r] = acc;
        }
        workgroupBarrier();
        for (var r = 0; r < MAXR; r++) {
            let e = t + 64 * r;
            if (e >= ipairs) { break; }
            let i = e / nu + hov;
            let u = e % nu;
            let k = slot(u, b);
            spec[i * b + k] = res[r].x;
            if (!is_real(u, b)) { spec[i * b + k + 1] = res[r].y; }
        }
        workgroupBarrier();
        // Rows back: inverse transform of the kept pixels, divided by the window.
        for (var p = t; p < rhe * rwe; p += 64) {
            let i = p / rwe + hov;
            let j = p % rwe + hov;
            var y = spec[i * b];
            if ((b & 1) == 0) { y += spec[i * b + 1] * select(1.0, -1.0, (j & 1) == 1); }
            for (var u = 1; u < (b + 1) / 2; u++) {
                let k = slot(u, b);
                let w = twi(u * j, b);
                y += 2.0 * (spec[i * b + k] * w.x - spec[i * b + k + 1] * w.y);
            }
            // lrintf gives LONG_MIN (clipped to 0) for a zero window weight (Cauchy, Parzen)
            // and for values beyond 32 bits.
            let wij = wint[i] * wint[j];
            let q = select(0.0, y / wij, wij != 0.0);
            let v = select(0.0, clamp(round(q), 0.0, 255.0), abs(q) < 2147483648.0);
            gpufx_write(vec3u(u32(x0 + j - hov), u32(y0 + i - hov), 0u), vec4f(v / 255.0, 0.0, 0.0, 1.0));
        }
        workgroupBarrier();
    }
}

@compute @workgroup_size(8, 8)
fn red(@builtin(workgroup_id) wg: vec3u, @builtin(num_workgroups) n: vec3u, @builtin(local_invocation_index) l: u32) {
    if ((params.planes & 4) != 0) { run(0, wg, n, l); }
}
@compute @workgroup_size(8, 8)
fn green(@builtin(workgroup_id) wg: vec3u, @builtin(num_workgroups) n: vec3u, @builtin(local_invocation_index) l: u32) {
    if ((params.planes & 1) != 0) { run(1, wg, n, l); }
}
@compute @workgroup_size(8, 8)
fn blue(@builtin(workgroup_id) wg: vec3u, @builtin(num_workgroups) n: vec3u, @builtin(local_invocation_index) l: u32) {
    if ((params.planes & 2) != 0) { run(2, wg, n, l); }
}
