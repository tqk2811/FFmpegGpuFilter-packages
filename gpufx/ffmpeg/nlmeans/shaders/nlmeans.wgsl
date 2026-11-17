// Non-local means on each R, G, B channel (FFmpeg vf_nlmeans.c): every pixel of the research
// window around the pixel is weighted by exp(-ssd / h^2), ssd being the sum of squared 8-bit
// differences between the patch around it and the patch around the pixel. Patch pixels
// outside the picture take the nearest edge pixel; the candidate itself must be inside.
//
// A workgroup takes an 8x8 tile. It loads the tile with the patch and research margins into
// workgroup memory (8-bit codes packed in a u32), then for each offset of the research window
// sums the squared differences along the patch rows once per tile row, and each pixel adds up
// the p row sums of its patch. The sums are integers, so the result is the same as summing
// the patch directly.
const MAXT = 58; // 8 + (21 - 1) + (31 - 1)
var<workgroup> tile: array<u32, 3364>; // MAXT * MAXT
var<workgroup> rs_r: array<u32, 224>;  // (8 + 21 - 1) rows of 8 row sums
var<workgroup> rs_g: array<u32, 224>;
var<workgroup> rs_b: array<u32, 224>;

fn unpack(v: u32) -> vec3i {
    return vec3i(i32(v & 255u), i32((v >> 8u) & 255u), i32((v >> 16u) & 255u));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u, @builtin(workgroup_id) wg: vec3u,
        @builtin(local_invocation_id) lid3: vec3u, @builtin(local_invocation_index) lid: u32) {
    let s = vec2i(textureDimensions(src));
    let c = vec2i(id.xy);
    let inside = all(c < s);
    let l = vec2i(lid3.xy);
    let t = i32(lid);
    // Even sizes are made odd, as FFmpeg does.
    let ph = (params.p | 1) / 2;
    let rh = (params.r | 1) / 2;
    let m = ph + rh;
    let ts = 8 + 2 * m;
    let org = vec2i(wg.xy) * 8 - m;
    for (var e = t; e < ts * ts; e += 64) {
        let p = clamp(org + vec2i(e % ts, e / ts), vec2i(0), s - 1);
        let v = vec3u(round(textureLoad(src, p, 0).rgb * 255.0));
        tile[e] = v.r | (v.g << 8u) | (v.b << 16u);
    }
    workgroupBarrier();
    let h = params.s * 10.0;
    let scale = 1.0 / (h * h);
    let max_diff = vec3i(i32(log(255.0) / scale));
    let rows = 8 + 2 * ph;
    var total = vec3f(0.0);
    var sum = vec3f(0.0);
    for (var oy = -rh; oy <= rh; oy++) {
        for (var ox = -rh; ox <= rh; ox++) {
            // Row sums: tile row y (patch rows of the tile, from -ph), column x.
            for (var e = t; e < rows * 8; e += 64) {
                let x = e % 8;
                let y = e / 8;
                let a0 = (y + rh) * ts + x + rh;
                let b0 = a0 + oy * ts + ox;
                var acc = vec3i(0);
                for (var d = 0; d <= 2 * ph; d++) {
                    let dd = unpack(tile[a0 + d]) - unpack(tile[b0 + d]);
                    acc += dd * dd;
                }
                rs_r[e] = u32(acc.r);
                rs_g[e] = u32(acc.g);
                rs_b[e] = u32(acc.b);
            }
            workgroupBarrier();
            let q = c + vec2i(ox, oy);
            if (inside && !(ox == 0 && oy == 0) && all(q >= vec2i(0)) && all(q < s)) {
                var ssd = vec3i(0);
                for (var d = 0; d <= 2 * ph; d++) {
                    let e = (l.y + d) * 8 + l.x;
                    ssd += vec3i(i32(rs_r[e]), i32(rs_g[e]), i32(rs_b[e]));
                }
                // FFmpeg's weight table stops before max_diff: that difference and above weigh 0.
                let w = select(vec3f(0.0), exp(-vec3f(ssd) * scale), ssd < max_diff);
                total += w;
                sum += w * vec3f(unpack(tile[(l.y + m + oy) * ts + l.x + m + ox]));
            }
            workgroupBarrier();
        }
    }
    if (!inside) { return; }
    let px = textureLoad(src, c, 0);
    total += 1.0;
    sum += vec3f(unpack(tile[(l.y + m) * ts + l.x + m]));
    let o = clamp(trunc(sum / total + 0.5), vec3f(0.0), vec3f(255.0));
    gpufx_write(id, vec4f(o / 255.0, px.a));
}
