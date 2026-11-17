// Non-local means on each R, G, B channel (FFmpeg vf_nlmeans.c): every pixel of the research
// window around the pixel is weighted by exp(-ssd / h^2), ssd being the sum of squared 8-bit
// differences between the patch around it and the patch around the pixel. Patch pixels
// outside the picture take the nearest edge pixel; the candidate itself must be inside.
fn code(p: vec2i, s: vec2i) -> vec3i {
    return vec3i(round(textureLoad(src, clamp(p, vec2i(0), s - 1), 0).rgb * 255.0));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let c = vec2i(id.xy);
    // Even sizes are made odd, as FFmpeg does.
    let ph = (params.p | 1) / 2;
    let rh = (params.r | 1) / 2;
    let h = params.s * 10.0;
    let scale = 1.0 / (h * h);
    let max_diff = vec3i(i32(log(255.0) / scale));
    var total = vec3f(0.0);
    var sum = vec3f(0.0);
    for (var oy = -rh; oy <= rh; oy++) {
        for (var ox = -rh; ox <= rh; ox++) {
            let q = c + vec2i(ox, oy);
            if ((ox == 0 && oy == 0) || any(q < vec2i(0)) || any(q >= s)) { continue; }
            var ssd = vec3i(0);
            for (var dy = -ph; dy <= ph; dy++) {
                for (var dx = -ph; dx <= ph; dx++) {
                    let d = code(c + vec2i(dx, dy), s) - code(q + vec2i(dx, dy), s);
                    ssd += d * d;
                }
            }
            // FFmpeg's weight table stops before max_diff: that difference and above weigh 0.
            let w = select(vec3f(0.0), exp(-vec3f(ssd) * scale), ssd < max_diff);
            total += w;
            sum += w * vec3f(code(q, s));
        }
    }
    let px = textureLoad(src, c, 0);
    total += 1.0;
    sum += vec3f(code(c, s));
    let o = clamp(trunc(sum / total + 0.5), vec3f(0.0), vec3f(255.0));
    gpufx_write(id, vec4f(o / 255.0, px.a));
}
