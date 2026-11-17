// FFmpeg haldclut (vf_lut3d.c): a Hald CLUT of level L is an L^3 x L^3 picture holding an
// L^2-entry-per-channel table, red fastest, then green, then blue, row by row.

// Number of entries per channel: L^2 where the picture is L^3 wide.
fn lut_size() -> i32 {
    let w = i32(textureDimensions(clut).x);
    var level = 1;
    while (level * level * level < w) { level++; }
    return level * level;
}

fn entry(r: i32, g: i32, b: i32, n: i32) -> vec3f {
    let w = i32(textureDimensions(clut).x);
    let i = r + g * n + b * n * n;
    return textureLoad(clut, vec2i(i % w, i / w), 0).rgb;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let c = textureLoad(src, vec2i(id.xy), 0);
    let n = lut_size();
    let s = clamp(c.rgb, vec3f(0.0), vec3f(1.0)) * f32(n - 1);
    if (params.interp == 0) {
        let p = vec3i(round(s));
        gpufx_write(id, vec4f(entry(p.x, p.y, p.z, n), c.a));
        return;
    }
    let p = vec3i(floor(s));
    let q = min(p + 1, vec3i(n - 1));
    let d = s - vec3f(p);
    let c000 = entry(p.x, p.y, p.z, n);
    let c111 = entry(q.x, q.y, q.z, n);
    let c100 = entry(q.x, p.y, p.z, n);
    let c010 = entry(p.x, q.y, p.z, n);
    let c001 = entry(p.x, p.y, q.z, n);
    let c110 = entry(q.x, q.y, p.z, n);
    let c101 = entry(q.x, p.y, q.z, n);
    let c011 = entry(p.x, q.y, q.z, n);
    var o: vec3f;
    if (params.interp == 1) {
        let c00 = mix(c000, c100, d.x);
        let c10 = mix(c010, c110, d.x);
        let c01 = mix(c001, c101, d.x);
        let c11 = mix(c011, c111, d.x);
        o = mix(mix(c00, c10, d.y), mix(c01, c11, d.y), d.z);
    } else if (d.x > d.y) {
        if (d.y > d.z) {
            o = (1.0 - d.x) * c000 + (d.x - d.y) * c100 + (d.y - d.z) * c110 + d.z * c111;
        } else if (d.x > d.z) {
            o = (1.0 - d.x) * c000 + (d.x - d.z) * c100 + (d.z - d.y) * c101 + d.y * c111;
        } else {
            o = (1.0 - d.z) * c000 + (d.z - d.x) * c001 + (d.x - d.y) * c101 + d.y * c111;
        }
    } else {
        if (d.z > d.y) {
            o = (1.0 - d.z) * c000 + (d.z - d.y) * c001 + (d.y - d.x) * c011 + d.x * c111;
        } else if (d.z > d.x) {
            o = (1.0 - d.y) * c000 + (d.y - d.z) * c010 + (d.z - d.x) * c011 + d.x * c111;
        } else {
            o = (1.0 - d.y) * c000 + (d.y - d.x) * c010 + (d.x - d.z) * c110 + d.z * c111;
        }
    }
    gpufx_write(id, vec4f(o, c.a));
}
