// hqx pixel-art magnification by 2, 3 or 4 (FFmpeg vf_hqx.c). The 3x3 neighbourhood gives an
// 8-bit pattern of the neighbours that differ from the centre in FFmpeg's integer YUV; FFmpeg's
// rules turn it into each sub-pixel, written for the top-left part of the block and mirrored
// or rotated for the others by permuting the neighbours. Pixels are FFmpeg's RGB32 words so
// the blends round as in C. Neighbours past the edge repeat the edge pixel.
fn gpufx_output_size(out_index: u32) -> vec2u {
    return gpufx_input_size(0u) * u32(clamp(params.n, 2, 4));
}

var<private> W: array<u32, 9>;
var<private> ks: u32;
var<private> w0: u32;
var<private> w1: u32;
var<private> w3: u32;
var<private> w4: u32;
var<private> w5: u32;
var<private> w7: u32;

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

fn ydiff(a: vec3i, b: vec3i) -> bool {
    let d = abs(a - b);
    return d.x > 48 || d.y > 7 || d.z > 6;
}

fn wdiff(a: u32, b: u32) -> bool {
    return ydiff(yuv(a), yuv(b));
}

fn i2(c1: u32, a: u32, c2: u32, b: u32, s: u32) -> u32 {
    return ((((((c1 & 0xff00ff00u) >> 8u) * a + ((c2 & 0xff00ff00u) >> 8u) * b) << (8u - s)) & 0xff00ff00u)
         | ((((c1 & 0x00ff00ffu) * a + (c2 & 0x00ff00ffu) * b) >> s) & 0x00ff00ffu));
}

fn i3(c1: u32, a: u32, c2: u32, b: u32, c3: u32, c: u32, s: u32) -> u32 {
    return ((((((c1 & 0xff00ff00u) >> 8u) * a + ((c2 & 0xff00ff00u) >> 8u) * b + ((c3 & 0xff00ff00u) >> 8u) * c) << (8u - s)) & 0xff00ff00u)
         | ((((c1 & 0x00ff00ffu) * a + (c2 & 0x00ff00ffu) * b + (c3 & 0x00ff00ffu) * c) >> s) & 0x00ff00ffu));
}

fn P(m: u32, r: u32) -> bool {
    return (ks & m) == r;
}

fn drop4(z: i32) -> i32 {
    return select(z, z - 1, z > 4);
}

// FFmpeg's INTERP_BOOTSTRAP: shuffles the pattern bits for the permutation `p` (rotated when
// `rot`) and picks the neighbours.
fn bootstrap(k: u32, p: array<i32, 9>, rot: bool) {
    ks = 0u;
    for (var n = 0; n < 9; n++) {
        if (n == 4) { continue; }
        let bit_in = select(drop4(n), 7 - drop4(n), rot);
        ks |= ((k >> u32(bit_in)) & 1u) << u32(drop4(p[n]));
    }
    w0 = W[p[0]]; w1 = W[p[1]]; w3 = W[p[3]]; w4 = W[p[4]]; w5 = W[p[5]]; w7 = W[p[7]];
}

fn hq2(k: u32, p: array<i32, 9>) -> u32 {
    bootstrap(k, p, false);
    if ((P(0xbfu, 0x37u) || P(0xdbu, 0x13u)) && wdiff(w1, w5)) { return i2(w4, 3u, w3, 1u, 2u); }
    if ((P(0xdbu, 0x49u) || P(0xefu, 0x6du)) && wdiff(w7, w3)) { return i2(w4, 3u, w1, 1u, 2u); }
    if ((P(0x0bu, 0x0bu) || P(0xfeu, 0x4au) || P(0xfeu, 0x1au)) && wdiff(w3, w1)) { return w4; }
    if ((P(0x6fu, 0x2au) || P(0x5bu, 0x0au) || P(0xbfu, 0x3au) || P(0xdfu, 0x5au) ||
         P(0x9fu, 0x8au) || P(0xcfu, 0x8au) || P(0xefu, 0x4eu) || P(0x3fu, 0x0eu) ||
         P(0xfbu, 0x5au) || P(0xbbu, 0x8au) || P(0x7fu, 0x5au) || P(0xafu, 0x8au) ||
         P(0xebu, 0x8au)) && wdiff(w3, w1)) { return i2(w4, 3u, w0, 1u, 2u); }
    if (P(0x0bu, 0x08u)) { return i3(w4, 2u, w0, 1u, w1, 1u, 2u); }
    if (P(0x0bu, 0x02u)) { return i3(w4, 2u, w0, 1u, w3, 1u, 2u); }
    if (P(0x2fu, 0x2fu)) { return i3(w4, 14u, w3, 1u, w1, 1u, 4u); }
    if (P(0xbfu, 0x37u) || P(0xdbu, 0x13u)) { return i3(w4, 5u, w1, 2u, w3, 1u, 3u); }
    if (P(0xdbu, 0x49u) || P(0xefu, 0x6du)) { return i3(w4, 5u, w3, 2u, w1, 1u, 3u); }
    if (P(0x1bu, 0x03u) || P(0x4fu, 0x43u) || P(0x8bu, 0x83u) || P(0x6bu, 0x43u)) { return i2(w4, 3u, w3, 1u, 2u); }
    if (P(0x4bu, 0x09u) || P(0x8bu, 0x89u) || P(0x1fu, 0x19u) || P(0x3bu, 0x19u)) { return i2(w4, 3u, w1, 1u, 2u); }
    if (P(0x7eu, 0x2au) || P(0xefu, 0xabu) || P(0xbfu, 0x8fu) || P(0x7eu, 0x0eu)) { return i3(w4, 2u, w3, 3u, w1, 3u, 3u); }
    if (P(0xfbu, 0x6au) || P(0x6fu, 0x6eu) || P(0x3fu, 0x3eu) || P(0xfbu, 0xfau) ||
        P(0xdfu, 0xdeu) || P(0xdfu, 0x1eu)) { return i2(w4, 3u, w0, 1u, 2u); }
    if (P(0x0au, 0x00u) || P(0x4fu, 0x4bu) || P(0x9fu, 0x1bu) || P(0x2fu, 0x0bu) ||
        P(0xbeu, 0x0au) || P(0xeeu, 0x0au) || P(0x7eu, 0x0au) || P(0xebu, 0x4bu) ||
        P(0x3bu, 0x1bu)) { return i3(w4, 2u, w3, 1u, w1, 1u, 2u); }
    return i3(w4, 6u, w3, 1u, w1, 1u, 3u);
}

// hq3x_interp_2x1: `second` picks dst01 instead of dst00.
fn hq3(k: u32, p: array<i32, 9>, rot: bool, second: bool) -> u32 {
    bootstrap(k, p, rot);
    if (!second) {
        if ((P(0xdbu, 0x49u) || P(0xefu, 0x6du)) && wdiff(w7, w3)) { return i2(w4, 3u, w1, 1u, 2u); }
        if ((P(0xbfu, 0x37u) || P(0xdbu, 0x13u)) && wdiff(w1, w5)) { return i2(w4, 3u, w3, 1u, 2u); }
        if ((P(0x0bu, 0x0bu) || P(0xfeu, 0x4au) || P(0xfeu, 0x1au)) && wdiff(w3, w1)) { return w4; }
        if ((P(0x6fu, 0x2au) || P(0x5bu, 0x0au) || P(0xbfu, 0x3au) || P(0xdfu, 0x5au) ||
             P(0x9fu, 0x8au) || P(0xcfu, 0x8au) || P(0xefu, 0x4eu) || P(0x3fu, 0x0eu) ||
             P(0xfbu, 0x5au) || P(0xbbu, 0x8au) || P(0x7fu, 0x5au) || P(0xafu, 0x8au) ||
             P(0xebu, 0x8au)) && wdiff(w3, w1)) { return i2(w4, 3u, w0, 1u, 2u); }
        if (P(0x4bu, 0x09u) || P(0x8bu, 0x89u) || P(0x1fu, 0x19u) || P(0x3bu, 0x19u)) { return i2(w4, 3u, w1, 1u, 2u); }
        if (P(0x1bu, 0x03u) || P(0x4fu, 0x43u) || P(0x8bu, 0x83u) || P(0x6bu, 0x43u)) { return i2(w4, 3u, w3, 1u, 2u); }
        if (P(0x7eu, 0x2au) || P(0xefu, 0xabu) || P(0xbfu, 0x8fu) || P(0x7eu, 0x0eu)) { return i2(w3, 1u, w1, 1u, 1u); }
        if (P(0x4fu, 0x4bu) || P(0x9fu, 0x1bu) || P(0x2fu, 0x0bu) || P(0xbeu, 0x0au) ||
            P(0xeeu, 0x0au) || P(0x7eu, 0x0au) || P(0xebu, 0x4bu) || P(0x3bu, 0x1bu)) { return i3(w4, 2u, w3, 7u, w1, 7u, 4u); }
        if (P(0x0bu, 0x08u) || P(0xf9u, 0x68u) || P(0xf3u, 0x62u) || P(0x6du, 0x6cu) ||
            P(0x67u, 0x66u) || P(0x3du, 0x3cu) || P(0x37u, 0x36u) || P(0xf9u, 0xf8u) ||
            P(0xddu, 0xdcu) || P(0xf3u, 0xf2u) || P(0xd7u, 0xd6u) || P(0xddu, 0x1cu) ||
            P(0xd7u, 0x16u) || P(0x0bu, 0x02u)) { return i2(w4, 3u, w0, 1u, 2u); }
        return i3(w4, 2u, w3, 1u, w1, 1u, 2u);
    }
    if ((P(0xfeu, 0xdeu) || P(0x9eu, 0x16u) || P(0xdau, 0x12u) || P(0x17u, 0x16u) ||
         P(0x5bu, 0x12u) || P(0xbbu, 0x12u)) && wdiff(w1, w5)) { return w4; }
    if ((P(0x0fu, 0x0bu) || P(0x5eu, 0x0au) || P(0xfbu, 0x7bu) || P(0x3bu, 0x0bu) ||
         P(0xbeu, 0x0au) || P(0x7au, 0x0au)) && wdiff(w3, w1)) { return w4; }
    if (P(0xbfu, 0x8fu) || P(0x7eu, 0x0eu) || P(0xbfu, 0x37u) || P(0xdbu, 0x13u)) { return i2(w1, 3u, w4, 1u, 2u); }
    if (P(0x02u, 0x00u) || P(0x7cu, 0x28u) || P(0xedu, 0xa9u) || P(0xf5u, 0xb4u) ||
        P(0xd9u, 0x90u)) { return i2(w4, 3u, w1, 1u, 2u); }
    if (P(0x4fu, 0x4bu) || P(0xfbu, 0x7bu) || P(0xfeu, 0x7eu) || P(0x9fu, 0x1bu) ||
        P(0x2fu, 0x0bu) || P(0xbeu, 0x0au) || P(0x7eu, 0x0au) || P(0xfbu, 0x4bu) ||
        P(0xfbu, 0xdbu) || P(0xfeu, 0xdeu) || P(0xfeu, 0x56u) || P(0x57u, 0x56u) ||
        P(0x97u, 0x16u) || P(0x3fu, 0x1eu) || P(0xdbu, 0x12u) || P(0xbbu, 0x12u)) { return i2(w4, 7u, w1, 1u, 3u); }
    return w4;
}

// hq4x_interp_2x2: `which` picks dst00, dst01, dst10 or dst11.
fn hq4(k: u32, p: array<i32, 9>, which: i32) -> u32 {
    bootstrap(k, p, false);
    let c00 = (P(0xbfu, 0x37u) || P(0xdbu, 0x13u)) && wdiff(w1, w5);
    let c01 = (P(0xdbu, 0x49u) || P(0xefu, 0x6du)) && wdiff(w7, w3);
    let c02 = (P(0x6fu, 0x2au) || P(0x5bu, 0x0au) || P(0xbfu, 0x3au) ||
               P(0xdfu, 0x5au) || P(0x9fu, 0x8au) || P(0xcfu, 0x8au) ||
               P(0xefu, 0x4eu) || P(0x3fu, 0x0eu) || P(0xfbu, 0x5au) ||
               P(0xbbu, 0x8au) || P(0x7fu, 0x5au) || P(0xafu, 0x8au) ||
               P(0xebu, 0x8au)) && wdiff(w3, w1);
    let c03 = P(0xdbu, 0x49u) || P(0xefu, 0x6du);
    let c04 = P(0xbfu, 0x37u) || P(0xdbu, 0x13u);
    let c05 = P(0x1bu, 0x03u) || P(0x4fu, 0x43u) || P(0x8bu, 0x83u) || P(0x6bu, 0x43u);
    let c06 = P(0x4bu, 0x09u) || P(0x8bu, 0x89u) || P(0x1fu, 0x19u) || P(0x3bu, 0x19u);
    let c07 = P(0x0bu, 0x08u) || P(0xf9u, 0x68u) || P(0xf3u, 0x62u) ||
              P(0x6du, 0x6cu) || P(0x67u, 0x66u) || P(0x3du, 0x3cu) ||
              P(0x37u, 0x36u) || P(0xf9u, 0xf8u) || P(0xddu, 0xdcu) ||
              P(0xf3u, 0xf2u) || P(0xd7u, 0xd6u) || P(0xddu, 0x1cu) ||
              P(0xd7u, 0x16u) || P(0x0bu, 0x02u);
    let c08 = (P(0x0fu, 0x0bu) || P(0x2bu, 0x0bu) || P(0xfeu, 0x4au) || P(0xfeu, 0x1au)) && wdiff(w3, w1);
    let c09 = P(0x2fu, 0x2fu);
    let c10 = P(0x0au, 0x00u);
    let c11 = P(0x0bu, 0x09u);
    let c12 = P(0x7eu, 0x2au) || P(0xefu, 0xabu);
    let c13 = P(0xbfu, 0x8fu) || P(0x7eu, 0x0eu);
    let c14 = P(0x4fu, 0x4bu) || P(0x9fu, 0x1bu) || P(0x2fu, 0x0bu) ||
              P(0xbeu, 0x0au) || P(0xeeu, 0x0au) || P(0x7eu, 0x0au) ||
              P(0xebu, 0x4bu) || P(0x3bu, 0x1bu);
    let c15 = P(0x0bu, 0x03u);

    if (which == 0) {
        if (c00) { return i2(w4, 5u, w3, 3u, 3u); }
        if (c01) { return i2(w4, 5u, w1, 3u, 3u); }
        if ((P(0x0bu, 0x0bu) || P(0xfeu, 0x4au) || P(0xfeu, 0x1au)) && wdiff(w3, w1)) { return w4; }
        if (c02) { return i2(w4, 5u, w0, 3u, 3u); }
        if (c03) { return i2(w4, 3u, w3, 1u, 2u); }
        if (c04) { return i2(w4, 3u, w1, 1u, 2u); }
        if (c05) { return i2(w4, 5u, w3, 3u, 3u); }
        if (c06) { return i2(w4, 5u, w1, 3u, 3u); }
        if (P(0x0fu, 0x0bu) || P(0x5eu, 0x0au) || P(0x2bu, 0x0bu) || P(0xbeu, 0x0au) ||
            P(0x7au, 0x0au) || P(0xeeu, 0x0au)) { return i2(w1, 1u, w3, 1u, 1u); }
        if (c07) { return i2(w4, 5u, w0, 3u, 3u); }
        return i3(w4, 2u, w1, 1u, w3, 1u, 2u);
    }
    if (which == 1) {
        if (c00) { return i2(w4, 7u, w3, 1u, 3u); }
        if (c08) { return w4; }
        if (c02) { return i2(w4, 3u, w0, 1u, 2u); }
        if (c09) { return w4; }
        if (c10) { return i3(w4, 5u, w1, 2u, w3, 1u, 3u); }
        if (P(0x0bu, 0x08u)) { return i3(w4, 5u, w1, 2u, w0, 1u, 3u); }
        if (c11) { return i2(w4, 5u, w1, 3u, 3u); }
        if (c04) { return i2(w1, 3u, w4, 1u, 2u); }
        if (c12) { return i3(w1, 2u, w4, 1u, w3, 1u, 2u); }
        if (c13) { return i2(w1, 5u, w3, 3u, 3u); }
        if (c05) { return i2(w4, 7u, w3, 1u, 3u); }
        if (P(0xf3u, 0x62u) || P(0x67u, 0x66u) || P(0x37u, 0x36u) || P(0xf3u, 0xf2u) ||
            P(0xd7u, 0xd6u) || P(0xd7u, 0x16u) || P(0x0bu, 0x02u)) { return i2(w4, 3u, w0, 1u, 2u); }
        if (c14) { return i2(w1, 1u, w4, 1u, 1u); }
        return i2(w4, 3u, w1, 1u, 2u);
    }
    if (which == 2) {
        if (c01) { return i2(w4, 7u, w1, 1u, 3u); }
        if (c08) { return w4; }
        if (c02) { return i2(w4, 3u, w0, 1u, 2u); }
        if (c09) { return w4; }
        if (c10) { return i3(w4, 5u, w3, 2u, w1, 1u, 3u); }
        if (P(0x0bu, 0x02u)) { return i3(w4, 5u, w3, 2u, w0, 1u, 3u); }
        if (c15) { return i2(w4, 5u, w3, 3u, 3u); }
        if (c03) { return i2(w3, 3u, w4, 1u, 2u); }
        if (c13) { return i3(w3, 2u, w4, 1u, w1, 1u, 2u); }
        if (c12) { return i2(w3, 5u, w1, 3u, 3u); }
        if (c06) { return i2(w4, 7u, w1, 1u, 3u); }
        if (P(0x0bu, 0x08u) || P(0xf9u, 0x68u) || P(0x6du, 0x6cu) || P(0x3du, 0x3cu) ||
            P(0xf9u, 0xf8u) || P(0xddu, 0xdcu) || P(0xddu, 0x1cu)) { return i2(w4, 3u, w0, 1u, 2u); }
        if (c14) { return i2(w3, 1u, w4, 1u, 1u); }
        return i2(w4, 3u, w3, 1u, 2u);
    }
    if ((P(0x7fu, 0x2bu) || P(0xefu, 0xabu) || P(0xbfu, 0x8fu) || P(0x7fu, 0x0fu)) && wdiff(w3, w1)) { return w4; }
    if (c02) { return i2(w4, 7u, w0, 1u, 3u); }
    if (c15) { return i2(w4, 7u, w3, 1u, 3u); }
    if (c11) { return i2(w4, 7u, w1, 1u, 3u); }
    if (P(0x0au, 0x00u) || P(0x7eu, 0x2au) || P(0xefu, 0xabu) || P(0xbfu, 0x8fu) ||
        P(0x7eu, 0x0eu)) { return i3(w4, 6u, w3, 1u, w1, 1u, 3u); }
    if (c07) { return i2(w4, 7u, w0, 1u, 3u); }
    return w4;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let n = clamp(params.n, 2, 4);
    let o = vec2i(id.xy);
    let c = o / n;
    let sub = o - c * n;
    for (var j = 0; j < 9; j++) {
        W[j] = fetch(c + vec2i(j % 3 - 1, j / 3 - 1));
    }
    let y4 = yuv(W[4]);
    var k = 0u;
    for (var j = 0; j < 9; j++) {
        if (j == 4) { continue; }
        let bit = u32(select(j, j - 1, j > 4));
        if (W[4] != W[j] && ydiff(y4, yuv(W[j]))) { k |= 1u << bit; }
    }
    let p_id = array<i32, 9>(0, 1, 2, 3, 4, 5, 6, 7, 8);
    let p_v = array<i32, 9>(2, 1, 0, 5, 4, 3, 8, 7, 6);
    let p_h = array<i32, 9>(6, 7, 8, 3, 4, 5, 0, 1, 2);
    let p_c = array<i32, 9>(8, 7, 6, 5, 4, 3, 2, 1, 0);
    let p_r = array<i32, 9>(2, 5, 8, 1, 4, 7, 0, 3, 6);
    let p_l = array<i32, 9>(6, 3, 0, 7, 4, 1, 8, 5, 2);
    // One call of each rule set, with the permutation picked first: every call site is
    // inlined, and sixteen copies made the shader too big for some Metal compilers.
    var r: u32;
    if (n == 2) {
        var p = p_id;
        switch sub.y * 2 + sub.x {
            case 0: { p = p_id; }
            case 1: { p = p_v; }
            case 2: { p = p_h; }
            default: { p = p_c; }
        }
        r = hq2(k, p);
    } else if (n == 3) {
        var p = p_id;
        var rot = false;
        var second = false;
        var centre = false;
        switch sub.y * 3 + sub.x {
            case 0: { p = p_id; }
            case 1: { p = p_id; second = true; }
            case 2: { p = p_r; rot = true; }
            case 5: { p = p_r; rot = true; second = true; }
            case 6: { p = p_l; rot = true; }
            case 3: { p = p_l; rot = true; second = true; }
            case 8: { p = p_c; }
            case 7: { p = p_c; second = true; }
            default: { centre = true; }
        }
        r = select(hq3(k, p, rot, second), W[4], centre);
    } else {
        // Quadrant q, then the position inside it; FFmpeg's pos lists give for each quadrant
        // which output (00, 01, 10, 11) lands at each of its four places.
        let q = (sub.y / 2) * 2 + sub.x / 2;
        let pos = (sub.y % 2) * 2 + sub.x % 2;
        var p = p_id;
        var which = pos;
        switch q {
            case 0: { p = p_id; which = pos; }
            case 1: { p = p_v; which = array<i32, 4>(1, 0, 3, 2)[pos]; }
            case 2: { p = p_h; which = array<i32, 4>(2, 3, 0, 1)[pos]; }
            default: { p = p_c; which = array<i32, 4>(3, 2, 1, 0)[pos]; }
        }
        r = hq4(k, p, which);
    }
    gpufx_write(id, vec4f(f32((r >> 16u) & 255u), f32((r >> 8u) & 255u), f32(r & 255u), f32(r >> 24u)) / 255.0);
}
