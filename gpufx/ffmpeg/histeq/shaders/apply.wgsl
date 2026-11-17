// Histeq, last pass: builds the lookup table entries the pixel needs from the cumulative
// histogram and scales its R, G, B by lut / luma, with the integer math of FFmpeg's vf_histeq.c.
fn unpack(c: vec4f) -> u32 {
    let b = vec4u(round(c * 255.0));
    return b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u);
}

fn lut(x: i32) -> i32 {
    let cum = unpack(textureLoad(total, vec2i(x, 0), 0));
    let size = textureDimensions(src);
    let n = size.x * size.y;
    let intensity = u32(params.intensity * 1000.0);
    let strength = i32(params.strength * 1000.0);
    var l: u32;
    // The product fits in 32 bits up to about 4 million pixels at the largest intensity.
    if (f32(cum) * f32(intensity) < 4.0e9) {
        l = cum * intensity / n;
    } else {
        l = u32(f32(cum) * f32(intensity) / f32(n));
    }
    return (strength * i32(l)) / 255 + ((255 - strength) * x) / 255;
}

fn hash(p: vec2u) -> f32 {
    var h = p.x * 1664525u + p.y * 1013904223u + 739187u;
    h ^= h >> 16u; h *= 2246822519u; h ^= h >> 13u; h *= 3266489917u; h ^= h >> 16u;
    return f32(h >> 8u) / 16777216.0;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let px = textureLoad(src, vec2i(id.xy), 0);
    var c = vec3i(round(px.rgb * 255.0));
    let luma = (55 * c.r + 182 * c.g + 19 * c.b) >> 8u;
    if (luma == 0) {
        gpufx_write(id, vec4f(0.0, 0.0, 0.0, px.a));
        return;
    }
    var l = lut(luma);
    if (params.antibanding != 0) {
        let weak = params.antibanding == 1;
        var lo = select(lut(luma - 1), (l + lut(luma - 1)) / 2, weak);
        var hi = l;
        if (luma < 255) { hi = select(lut(luma + 1), (l + lut(luma + 1)) / 2, weak); }
        if (lo != hi) {
            l = lo + i32(floor(f32(hi - lo + 1) * hash(id.xy)));
        }
    }
    let m = max(max(c.r, c.g), c.b);
    var o: vec3u;
    if ((m * l) / luma > 255) {
        o = vec3u((c * 255) / m);
    } else {
        // FFmpeg multiplies unsigned codes by the signed entry, which can be negative when
        // strength is above 0.255, and keeps the low 8 bits: the same wrap-around here.
        o = (vec3u(c) * bitcast<u32>(l)) / u32(luma);
    }
    gpufx_write(id, vec4f(vec3f(o & vec3u(255u)) / 255.0, px.a));
}
