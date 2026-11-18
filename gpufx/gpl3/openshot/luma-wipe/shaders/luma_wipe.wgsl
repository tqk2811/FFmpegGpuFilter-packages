// Luma wipe over the OpenShot luma images (textures/, GPL-3.0-or-later, see README.md).
// A pixel switches to the second clip once `progress` passes the brightness of the
// image there; `softness` blends over that many luma steps.

fn luma(uv: vec2f) -> f32 {
    let n = params.pattern;
    let count_a = i32(textureNumLayers(lumas_a));
    if (n < count_a) { return textureSampleLevel(lumas_a, smp, uv, n, 0.0).r; }
    return textureSampleLevel(lumas_b, smp, uv, n - count_a, 0.0).r;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let uv = gpufx_uv(id);
    let a = textureSampleLevel(first, smp, uv, 0.0);
    let b = textureSampleLevel(second, smp, uv, 0.0);
    // Exact clips at both ends.
    if (params.progress <= 0.0) { gpufx_write(id, a); return; }
    if (params.progress >= 1.0) { gpufx_write(id, b); return; }
    var l = luma(uv);
    if (params.invert != 0u) { l = 1.0 - l; }
    let soft = max(params.softness, 1e-4);
    // The edge runs from below black (nothing switched) to above white (all switched).
    let p = params.progress * (1.0 + soft);
    gpufx_write(id, mix(a, b, smoothstep(l, l + soft, p)));
}
