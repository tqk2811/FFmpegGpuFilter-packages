// EPX / Scale2x and Scale3x pixel-art magnification (FFmpeg vf_epx.c). Pixels are compared as
// whole RGBA 8-bit values; neighbours past the edge repeat the edge pixel.
fn gpufx_output_size(out_index: u32) -> vec2u {
    return gpufx_input_size(0u) * u32(clamp(params.n, 2, 3));
}

fn px(p: vec2i) -> vec4u {
    let s = vec2i(textureDimensions(src));
    return vec4u(round(textureLoad(src, clamp(p, vec2i(0), s - 1), 0) * 255.0));
}

fn eq(a: vec4u, b: vec4u) -> bool {
    return all(a == b);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let n = clamp(params.n, 2, 3);
    let o = vec2i(id.xy);
    let c = o / n;
    let k = o - c * n;
    let A = px(c + vec2i(-1, -1));
    let B = px(c + vec2i(0, -1));
    let C = px(c + vec2i(1, -1));
    let D = px(c + vec2i(-1, 0));
    let E = px(c);
    let F = px(c + vec2i(1, 0));
    let G = px(c + vec2i(-1, 1));
    let H = px(c + vec2i(0, 1));
    let I = px(c + vec2i(1, 1));
    var r = E;
    if (!eq(B, H) && !eq(D, F)) {
        let i = k.y * n + k.x;
        if (n == 2) {
            switch i {
                case 0: { if (eq(D, B)) { r = D; } }
                case 1: { if (eq(B, F)) { r = F; } }
                case 2: { if (eq(D, H)) { r = D; } }
                default: { if (eq(H, F)) { r = F; } }
            }
        } else {
            switch i {
                case 0: { if (eq(D, B)) { r = D; } }
                case 1: { if ((eq(D, B) && !eq(E, C)) || (eq(B, F) && !eq(E, A))) { r = B; } }
                case 2: { if (eq(B, F)) { r = F; } }
                case 3: { if ((eq(D, B) && !eq(E, G)) || (eq(D, H) && !eq(E, A))) { r = D; } }
                case 5: { if ((eq(B, F) && !eq(E, I)) || (eq(H, F) && !eq(E, C))) { r = F; } }
                case 6: { if (eq(D, H)) { r = D; } }
                case 7: { if ((eq(D, H) && !eq(E, I)) || (eq(H, F) && !eq(E, G))) { r = H; } }
                case 8: { if (eq(H, F)) { r = F; } }
                default: {}
            }
        }
    }
    gpufx_write(id, vec4f(r) / 255.0);
}
