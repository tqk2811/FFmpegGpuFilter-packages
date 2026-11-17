// Zone plate test pattern (FFmpeg vsrc_testsrc.c, zoneplate): a sine lookup table indexed by a
// phase that is a polynomial in x, y and t, with FFmpeg's 32-bit integer arithmetic (wrapping)
// so the pattern matches pixel for pixel. FFmpeg writes full-range Y'CbCr; it is turned into RGB
// here with full-range BT.601.
fn lut(phase: i32) -> f32 {
    let size = 1 << u32(clamp(params.lut_precision, 4, 16));
    let i = phase & (size - 1);
    // lrintf rounds half to even, like WGSL's round.
    return round(255.0 * (0.5 + 0.5 * sin((2.0 * 3.14159265358979 * f32(i)) / f32(size))));
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let base = textureLoad(src, vec2i(id.xy), 0);
    let w = i32(globals.size.x);
    let h = i32(globals.size.y);
    let i = i32(id.x);
    let j = i32(id.y);
    // The frame number in FFmpeg's time base of 1 / rate.
    let rate = params.rate;
    let pts = i32(floor(f32(globals.time_int) * rate + globals.time_frac * rate + 0.5));
    let t = pts + params.to;
    let x = -(w / 2) - params.xo + i;
    let y = -(h / 2) - params.yo + j;
    let skxy = 0xffff / max(w / 2, 1);
    let skx2 = 0xffff / w;
    let dkxy = params.kxy * y * skxy;
    let nky2kt2 = (params.ky2 * y * y) / h + ((params.kt2 * t * t) >> 1u);
    var phase = params.k0;
    phase += params.kx * (i + 1) + params.ky * (j + 1) + params.kt * t;
    phase += params.kxt * t * (i + 1) + params.kyt * t * (j + 1);
    phase += (dkxy * (x + 1)) >> 16u;
    phase += ((params.kx2 * x * x * skx2) >> 16u) + nky2kt2;
    let yv = lut(phase);
    let u = lut(phase + params.ku) - 128.0;
    let v = lut(phase + params.kv) - 128.0;
    let rgb = vec3f(yv + 1.402 * v, yv - 0.344136 * u - 0.714136 * v, yv + 1.772 * u) / 255.0;
    gpufx_write(id, vec4f(mix(base.rgb, clamp(rgb, vec3f(0.0), vec3f(1.0)), params.opacity), mix(base.a, 1.0, params.opacity)));
}
