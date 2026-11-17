// xBR pixel-art magnification by 2, 3 or 4 (FFmpeg vf_xbr.c). Pixels are handled as FFmpeg's
// RGB32 words (B in the low byte, then G, R, A) so the bit-mask blends round exactly as in C;
// colors are compared through FFmpeg's integer YUV. Each thread works out the whole n x n block
// of its source pixel and keeps its own sub-pixel. Neighbours past the edge repeat the edge.
fn gpufx_output_size(out_index: u32) -> vec2u {
    return gpufx_input_size(0u) * u32(clamp(params.n, 2, 4));
}

const LB_MASK: u32 = 0x00FEFEFEu;
const RB_MASK: u32 = 0x00FF00FFu;
const G_MASK: u32 = 0x0000FF00u;

var<private> E: array<u32, 16>;

fn fetch(p: vec2i) -> u32 {
    let s = vec2i(textureDimensions(src));
    let c = vec4u(round(textureLoad(src, clamp(p, vec2i(0), s - 1), 0) * 255.0));
    return c.b | (c.g << 8u) | (c.r << 16u) | (c.a << 24u);
}

// FFmpeg's rgbtoyuv table entry, as separate Y, U, V.
fn yuv(p: u32) -> vec3i {
    let b = i32(p & 255u);
    let g = i32((p >> 8u) & 255u);
    let r = i32((p >> 16u) & 255u);
    let bg = b - g;
    let rg = r - g;
    let u = (-169 * rg + 500 * bg) / 1000 + 128;
    let v = (500 * rg - 81 * bg) / 1000 + 128;
    let startg = max(max(-bg, -rg), 0);
    let y = (299 * rg + 1000 * startg + 114 * bg) / 1000 + g - startg;
    return vec3i(y, u, v);
}

fn df(a: u32, b: u32) -> u32 {
    let d = abs(yuv(a) - yuv(b));
    return u32(d.x + d.y + d.z);
}

fn eqc(a: u32, b: u32) -> bool {
    return df(a, b) < 155u;
}

fn blend(a: u32, b: u32, m: u32, s: u32) -> u32 {
    return (RB_MASK & ((a & RB_MASK) + ((((b & RB_MASK) - (a & RB_MASK)) * m) >> s)))
         | (G_MASK & ((a & G_MASK) + ((((b & G_MASK) - (a & G_MASK)) * m) >> s)));
}

fn b128(a: u32, b: u32) -> u32 { return ((a & LB_MASK) >> 1u) + ((b & LB_MASK) >> 1u); }
fn b32(a: u32, b: u32) -> u32 { return blend(a, b, 1u, 3u); }
fn b64(a: u32, b: u32) -> u32 { return blend(a, b, 1u, 2u); }
fn b192(a: u32, b: u32) -> u32 { return blend(a, b, 3u, 2u); }
fn b224(a: u32, b: u32) -> u32 { return blend(a, b, 7u, 3u); }

// One corner of FFmpeg's FILT2/FILT3/FILT4. `N` holds the macro's block indices, in the order
// the macro of that scale takes them.
fn filt(n: i32, PE: u32, PI: u32, PH: u32, PF: u32, PG: u32, PC: u32, PD: u32, PB: u32, PA: u32,
        G5: u32, C4: u32, G0: u32, D0: u32, C1: u32, B1: u32, F4: u32, I4: u32, H5: u32, I5: u32,
        A0: u32, A1: u32, N: array<i32, 16>) {
    if (PE == PH || PE == PF) { return; }
    let e = df(PE, PC) + df(PE, PG) + df(PI, H5) + df(PI, F4) + (df(PH, PF) << 2u);
    let i = df(PH, PD) + df(PH, I5) + df(PF, I4) + df(PF, PB) + (df(PE, PI) << 2u);
    if (e > i) { return; }
    let px = select(PH, PF, df(PE, PF) <= df(PE, PH));
    var cond: bool;
    if (n == 3) {
        cond = (!eqc(PF, PB) && !eqc(PF, PC)) || (!eqc(PH, PD) && !eqc(PH, PG))
            || (eqc(PE, PI) && ((!eqc(PF, F4) && !eqc(PF, I4)) || (!eqc(PH, H5) && !eqc(PH, I5))))
            || eqc(PE, PG) || eqc(PE, PC);
    } else {
        cond = (!eqc(PF, PB) && !eqc(PH, PD)) || (eqc(PE, PI) && (!eqc(PF, I4) && !eqc(PH, I5)))
            || eqc(PE, PG) || eqc(PE, PC);
    }
    if (e < i && cond) {
        let ke = df(PF, PG);
        let ki = df(PH, PC);
        let left = (ke << 1u) <= ki && PE != PG && PD != PG;
        let up = ke >= (ki << 1u) && PE != PC && PB != PC;
        if (n == 2) {
            if (left && up) {
                E[N[3]] = b224(E[N[3]], px);
                E[N[2]] = b64(E[N[2]], px);
                E[N[1]] = E[N[2]];
            } else if (left) {
                E[N[3]] = b192(E[N[3]], px);
                E[N[2]] = b64(E[N[2]], px);
            } else if (up) {
                E[N[3]] = b192(E[N[3]], px);
                E[N[1]] = b64(E[N[1]], px);
            } else {
                E[N[3]] = b128(E[N[3]], px);
            }
        } else if (n == 3) {
            if (left && up) {
                E[N[7]] = b192(E[N[7]], px);
                E[N[6]] = b64(E[N[6]], px);
                E[N[5]] = E[N[7]];
                E[N[2]] = E[N[6]];
                E[N[8]] = px;
            } else if (left) {
                E[N[7]] = b192(E[N[7]], px);
                E[N[5]] = b64(E[N[5]], px);
                E[N[6]] = b64(E[N[6]], px);
                E[N[8]] = px;
            } else if (up) {
                E[N[5]] = b192(E[N[5]], px);
                E[N[7]] = b64(E[N[7]], px);
                E[N[2]] = b64(E[N[2]], px);
                E[N[8]] = px;
            } else {
                E[N[8]] = b224(E[N[8]], px);
                E[N[5]] = b32(E[N[5]], px);
                E[N[7]] = b32(E[N[7]], px);
            }
        } else {
            // FILT4 names its indices N15, N14, N11, N3, N7, N10, N13, N12, N9, N6, N2, N1, N5,
            // N8, N4, N0: N[0] is N15, N[1] N14, N[2] N11, N[3] N3, N[4] N7, N[5] N10, N[6] N13,
            // N[7] N12.
            if (left && up) {
                E[N[6]] = b192(E[N[6]], px);
                E[N[7]] = b64(E[N[7]], px);
                E[N[0]] = px; E[N[1]] = px; E[N[2]] = px;
                E[N[5]] = E[N[7]]; E[N[3]] = E[N[7]];
                E[N[4]] = E[N[6]];
            } else if (left) {
                E[N[2]] = b192(E[N[2]], px);
                E[N[6]] = b192(E[N[6]], px);
                E[N[5]] = b64(E[N[5]], px);
                E[N[7]] = b64(E[N[7]], px);
                E[N[1]] = px;
                E[N[0]] = px;
            } else if (up) {
                E[N[1]] = b192(E[N[1]], px);
                E[N[4]] = b192(E[N[4]], px);
                E[N[5]] = b64(E[N[5]], px);
                E[N[3]] = b64(E[N[3]], px);
                E[N[2]] = px;
                E[N[0]] = px;
            } else {
                E[N[2]] = b128(E[N[2]], px);
                E[N[1]] = b128(E[N[1]], px);
                E[N[0]] = px;
            }
        }
    } else {
        // N3 of FILT2, N8 of FILT3, N15 (first) of FILT4.
        let last = select(select(N[3], N[8], n == 3), N[0], n == 4);
        E[last] = b128(E[last], px);
    }
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let n = clamp(params.n, 2, 4);
    let o = vec2i(id.xy);
    let c = o / n;

    let B1 = fetch(c + vec2i(0, -2));
    let A1 = fetch(c + vec2i(-1, -2));
    let C1 = fetch(c + vec2i(1, -2));
    let A0 = fetch(c + vec2i(-2, -1));
    let PA = fetch(c + vec2i(-1, -1));
    let PB = fetch(c + vec2i(0, -1));
    let PC = fetch(c + vec2i(1, -1));
    let C4 = fetch(c + vec2i(2, -1));
    let D0 = fetch(c + vec2i(-2, 0));
    let PD = fetch(c + vec2i(-1, 0));
    let PE = fetch(c);
    let PF = fetch(c + vec2i(1, 0));
    let F4 = fetch(c + vec2i(2, 0));
    let G0 = fetch(c + vec2i(-2, 1));
    let PG = fetch(c + vec2i(-1, 1));
    let PH = fetch(c + vec2i(0, 1));
    let PI = fetch(c + vec2i(1, 1));
    let I4 = fetch(c + vec2i(2, 1));
    let G5 = fetch(c + vec2i(-1, 2));
    let H5 = fetch(c + vec2i(0, 2));
    let I5 = fetch(c + vec2i(1, 2));

    for (var k = 0; k < 16; k++) { E[k] = PE; }
    // Block index = row * n + column: FFmpeg's nl, nl1, nl2 are n, 2n, 3n here.
    let l = n;
    let l1 = 2 * n;
    let l2 = 3 * n;
    if (n == 2) {
        filt(2, PE, PI, PH, PF, PG, PC, PD, PB, PA, G5, C4, G0, D0, C1, B1, F4, I4, H5, I5, A0, A1,
             array<i32, 16>(0, 1, l, l + 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        filt(2, PE, PC, PF, PB, PI, PA, PH, PD, PG, I4, A1, I5, H5, A0, D0, B1, C1, F4, C4, G5, G0,
             array<i32, 16>(l, 0, l + 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        filt(2, PE, PA, PB, PD, PC, PG, PF, PH, PI, C1, G0, C4, F4, G5, H5, D0, A0, B1, A1, I4, I5,
             array<i32, 16>(l + 1, l, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        filt(2, PE, PG, PD, PH, PA, PI, PB, PF, PC, A0, I5, A1, B1, I4, F4, H5, G5, D0, G0, C1, C4,
             array<i32, 16>(1, l + 1, 0, l, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
    } else if (n == 3) {
        filt(3, PE, PI, PH, PF, PG, PC, PD, PB, PA, G5, C4, G0, D0, C1, B1, F4, I4, H5, I5, A0, A1,
             array<i32, 16>(0, 1, 2, l, l + 1, l + 2, l1, l1 + 1, l1 + 2, 0, 0, 0, 0, 0, 0, 0));
        filt(3, PE, PC, PF, PB, PI, PA, PH, PD, PG, I4, A1, I5, H5, A0, D0, B1, C1, F4, C4, G5, G0,
             array<i32, 16>(l1, l, 0, l1 + 1, l + 1, 1, l1 + 2, l + 2, 2, 0, 0, 0, 0, 0, 0, 0));
        filt(3, PE, PA, PB, PD, PC, PG, PF, PH, PI, C1, G0, C4, F4, G5, H5, D0, A0, B1, A1, I4, I5,
             array<i32, 16>(l1 + 2, l1 + 1, l1, l + 2, l + 1, l, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0));
        filt(3, PE, PG, PD, PH, PA, PI, PB, PF, PC, A0, I5, A1, B1, I4, F4, H5, G5, D0, G0, C1, C4,
             array<i32, 16>(2, l + 2, l1 + 2, 1, l + 1, l1 + 1, 0, l, l1, 0, 0, 0, 0, 0, 0, 0));
    } else {
        filt(4, PE, PI, PH, PF, PG, PC, PD, PB, PA, G5, C4, G0, D0, C1, B1, F4, I4, H5, I5, A0, A1,
             array<i32, 16>(l2 + 3, l2 + 2, l1 + 3, 3, l + 3, l1 + 2, l2 + 1, l2, l1 + 1, l + 2, 2, 1, l + 1, l1, l, 0));
        filt(4, PE, PC, PF, PB, PI, PA, PH, PD, PG, I4, A1, I5, H5, A0, D0, B1, C1, F4, C4, G5, G0,
             array<i32, 16>(3, l + 3, 2, 0, 1, l + 2, l1 + 3, l2 + 3, l1 + 2, l + 1, l, l1, l1 + 1, l2 + 2, l2 + 1, l2));
        filt(4, PE, PA, PB, PD, PC, PG, PF, PH, PI, C1, G0, C4, F4, G5, H5, D0, A0, B1, A1, I4, I5,
             array<i32, 16>(0, 1, l, l2, l1, l + 1, 2, 3, l + 2, l1 + 1, l2 + 1, l2 + 2, l1 + 2, l + 3, l1 + 3, l2 + 3));
        filt(4, PE, PG, PD, PH, PA, PI, PB, PF, PC, A0, I5, A1, B1, I4, F4, H5, G5, D0, G0, C1, C4,
             array<i32, 16>(l2, l1, l2 + 1, l2 + 3, l2 + 2, l1 + 1, l, 0, l + 1, l1 + 2, l1 + 3, l + 3, l + 2, 1, 2, 3));
    }

    let k = o - c * n;
    let r = E[k.y * n + k.x];
    // FFmpeg's blends clear the alpha byte; the source pixel's alpha is kept instead.
    let a = f32(PE >> 24u);
    gpufx_write(id, vec4f(f32((r >> 16u) & 255u), f32((r >> 8u) & 255u), f32(r & 255u), a) / 255.0);
}
