// Super 2xSaI pixel-art magnification by 2 (FFmpeg vf_super2xsai.c). Pixels are compared as
// whole RGBA 8-bit values and blended per byte with FFmpeg's bit masks, so the averages round
// the same way. Neighbours past the edge repeat the edge pixel.
fn gpufx_output_size(out_index: u32) -> vec2u {
    return gpufx_input_size(0u) * 2u;
}

var<private> col: array<array<vec4u, 4>, 4>;

fn eq(a: vec4u, b: vec4u) -> bool {
    return all(a == b);
}

fn ne(a: vec4u, b: vec4u) -> bool {
    return any(a != b);
}

fn interp(a: vec4u, b: vec4u) -> vec4u {
    return (a >> vec4u(1u)) + (b >> vec4u(1u)) + (a & b & vec4u(1u));
}

fn qinterp(a: vec4u, b: vec4u, c: vec4u, d: vec4u) -> vec4u {
    let t = vec4u(2u);
    let m = vec4u(3u);
    return (a >> t) + (b >> t) + (c >> t) + (d >> t) + ((((a & m) + (b & m) + (c & m) + (d & m)) >> t) & m);
}

fn res(a: vec4u, b: vec4u, c: vec4u, d: vec4u) -> i32 {
    return select(0, 1, ne(a, c) || ne(a, d)) - select(0, 1, ne(b, c) || ne(b, d));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let c = vec2i(id.xy) / 2;
    // col[r][k] is the pixel at row offset r - 1 and column offset k - 1.
    for (var r = 0; r < 4; r++) {
        for (var k = 0; k < 4; k++) {
            let p = clamp(c + vec2i(k - 1, r - 1), vec2i(0), s - 1);
            col[r][k] = vec4u(round(textureLoad(src, p, 0) * 255.0));
        }
    }
    var p1a: vec4u;
    var p1b: vec4u;
    var p2a: vec4u;
    var p2b: vec4u;

    if (eq(col[2][1], col[1][2]) && ne(col[1][1], col[2][2])) {
        p2b = col[2][1];
        p1b = p2b;
    } else if (eq(col[1][1], col[2][2]) && ne(col[2][1], col[1][2])) {
        p2b = col[1][1];
        p1b = p2b;
    } else if (eq(col[1][1], col[2][2]) && eq(col[2][1], col[1][2])) {
        var r = 0;
        r += res(col[1][2], col[1][1], col[1][0], col[3][1]);
        r += res(col[1][2], col[1][1], col[2][0], col[0][1]);
        r += res(col[1][2], col[1][1], col[3][2], col[2][3]);
        r += res(col[1][2], col[1][1], col[0][2], col[1][3]);
        if (r > 0) {
            p1b = col[1][2];
        } else if (r < 0) {
            p1b = col[1][1];
        } else {
            p1b = interp(col[1][1], col[1][2]);
        }
        p2b = p1b;
    } else {
        if (eq(col[1][2], col[2][2]) && eq(col[2][2], col[3][1]) && ne(col[2][1], col[3][2]) && ne(col[2][2], col[3][0])) {
            p2b = qinterp(col[2][2], col[2][2], col[2][2], col[2][1]);
        } else if (eq(col[1][1], col[2][1]) && eq(col[2][1], col[3][2]) && ne(col[3][1], col[2][2]) && ne(col[2][1], col[3][3])) {
            p2b = qinterp(col[2][1], col[2][1], col[2][1], col[2][2]);
        } else {
            p2b = interp(col[2][1], col[2][2]);
        }
        if (eq(col[1][2], col[2][2]) && eq(col[1][2], col[0][1]) && ne(col[1][1], col[0][2]) && ne(col[1][2], col[0][0])) {
            p1b = qinterp(col[1][2], col[1][2], col[1][2], col[1][1]);
        } else if (eq(col[1][1], col[2][1]) && eq(col[1][1], col[0][2]) && ne(col[0][1], col[1][2]) && ne(col[1][1], col[0][3])) {
            p1b = qinterp(col[1][2], col[1][1], col[1][1], col[1][1]);
        } else {
            p1b = interp(col[1][1], col[1][2]);
        }
    }

    if (eq(col[1][1], col[2][2]) && ne(col[2][1], col[1][2]) && eq(col[1][0], col[1][1]) && ne(col[1][1], col[3][2])) {
        p2a = interp(col[2][1], col[1][1]);
    } else if (eq(col[1][1], col[2][0]) && eq(col[1][2], col[1][1]) && ne(col[1][0], col[2][1]) && ne(col[1][1], col[3][0])) {
        p2a = interp(col[2][1], col[1][1]);
    } else {
        p2a = col[2][1];
    }

    if (eq(col[2][1], col[1][2]) && ne(col[1][1], col[2][2]) && eq(col[2][0], col[2][1]) && ne(col[2][1], col[0][2])) {
        p1a = interp(col[2][1], col[1][1]);
    } else if (eq(col[1][0], col[2][1]) && eq(col[2][2], col[2][1]) && ne(col[2][0], col[1][1]) && ne(col[2][1], col[0][0])) {
        p1a = interp(col[2][1], col[1][1]);
    } else {
        p1a = col[1][1];
    }

    let k = vec2i(id.xy) - c * 2;
    var o: vec4u;
    if (k.y == 0) { o = select(p1a, p1b, k.x == 1); } else { o = select(p2a, p2b, k.x == 1); }
    gpufx_write(id, vec4f(o) / 255.0);
}
