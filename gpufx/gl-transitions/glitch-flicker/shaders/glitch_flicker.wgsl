// Port of GlitchFlicker.glsl from gl-transitions (author: bread, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchFlicker.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn sat(x: f32) -> f32 { return clamp(x, 0.0, 1.0); }

fn hash12(p0: vec2f) -> f32 {
    var p = fract(p0 * vec2f(443.8975, 397.2973));
    p += dot(p, p.yx + 19.19);
    return fract(p.x * p.y);
}

fn safe_uv(uv: vec2f) -> vec2f {
    return clamp(uv, vec2f(0.001), vec2f(0.999));
}

// 24fps reference-matched reveal curve. Non-monotonic on purpose: the reference flashes back to the old clip.
fn frame_reveal(f: f32) -> f32 {
    if (f < 0.5) { return 0.00; }
    if (f < 1.5) { return 0.28; }
    if (f < 2.5) { return 0.43; }
    if (f < 3.5) { return 0.46; }
    if (f < 4.5) { return 0.38; }
    if (f < 5.5) { return 0.48; }
    if (f < 6.5) { return 0.26; }
    if (f < 7.5) { return 0.10; }
    if (f < 8.5) { return 0.00; }
    if (f < 9.5) { return 0.00; }
    if (f < 10.5) { return 0.30; }
    if (f < 11.5) { return 0.58; }
    if (f < 12.5) { return 1.00; }
    if (f < 13.5) { return 0.70; }
    if (f < 14.5) { return 0.42; }
    if (f < 15.5) { return 0.55; }
    if (f < 16.5) { return 0.72; }
    if (f < 17.5) { return 0.88; }
    if (f < 18.5) { return 0.34; }
    if (f < 19.5) { return 0.48; }
    if (f < 20.5) { return 0.56; }
    if (f < 21.5) { return 0.76; }
    if (f < 22.5) { return 0.93; }
    return 1.00;
}

fn frame_glitch(f: f32) -> f32 {
    if (f < 0.5) { return 0.00; }
    if (f < 6.5) { return 0.92; }
    if (f < 10.5) { return 0.38; }
    if (f < 11.5) { return 0.78; }
    if (f < 12.5) { return 0.12; }
    if (f < 17.5) { return 0.74; }
    if (f < 22.5) { return 0.88; }
    if (f < 23.5) { return 0.28; }
    return 0.00;
}

fn chroma_from(uv: vec2f, amt: f32) -> vec4f {
    let o = vec2f(amt, 0.0);
    let center = from_color(safe_uv(uv));
    return vec4f(from_color(safe_uv(uv + o)).r, center.g, from_color(safe_uv(uv - o)).b, center.a);
}

fn chroma_to(uv: vec2f, amt: f32) -> vec4f {
    let o = vec2f(amt, 0.0);
    let center = to_color(safe_uv(uv));
    return vec4f(to_color(safe_uv(uv - o)).r, center.g, to_color(safe_uv(uv + o)).b, center.a);
}

fn block_mask(uv: vec2f, f: f32) -> f32 {
    let big = floor(uv * vec2f(4.0, 2.0));
    let small = floor(uv * vec2f(8.0, 4.0));
    let wide = step(0.48, hash12(vec2f(big.x, f * 1.37)));
    let chunks = step(0.56, hash12(small + vec2f(f * 2.11, f * 0.73)));
    let vertical_cut = smoothstep(-0.035, 0.035, uv.x - mix(0.18, 0.78, hash12(vec2f(f, 4.7))));
    return sat(mix(wide, chunks, 0.38) * 0.72 + vertical_cut * 0.28);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let frame_rate = params.frame_rate;
    let f = floor(progress * frame_rate);
    // The 24-step tables are read in step with the frames, whatever frame_rate is.
    let step24 = f * 24.0 / max(frame_rate, 1.0);
    let reveal = frame_reveal(step24);
    let glitch = frame_glitch(step24) * (1.0 - smoothstep(0.96, 1.0, progress));

    let rnd = hash12(vec2f(f, 9.13));
    let jitter = vec2f((rnd - 0.5) * 0.042, (hash12(vec2f(f, 2.71)) - 0.5) * 0.010) * glitch;

    let from_uv = safe_uv(uv + jitter);
    let to_uv = safe_uv(uv - jitter * 0.55);

    let block = block_mask(uv, f);
    var local_reveal = sat(reveal
        + (block - 0.5) * params.block_amount * glitch
        + (hash12(vec2f(f, floor(uv.y * 9.0))) - 0.5) * 0.18 * glitch);
    local_reveal = smoothstep(0.22, 0.78, local_reveal);

    let old_clip = chroma_from(from_uv, params.rgb_offset * glitch);
    let new_clip = chroma_to(to_uv, params.rgb_offset * glitch);

    let color = mix(old_clip, new_clip, local_reveal);

    let left_wash = (1.0 - smoothstep(0.10, 0.78, uv.x)) * glitch;
    let cyan_wash = smoothstep(0.08, 0.62, uv.x) * (1.0 - smoothstep(0.86, 1.0, uv.x)) * glitch;

    let red_ghost = old_clip.rgb * vec3f(1.34, 0.42, 0.38);
    let cyan_ghost = new_clip.rgb * vec3f(0.48, 1.12, 1.24);

    var rgb = mix(color.rgb, red_ghost, left_wash * params.red_cyan * 0.42);
    rgb = mix(rgb, cyan_ghost, cyan_wash * params.red_cyan * 0.30);

    // Keeps the old circular "drop zone" visible as a translucent flash, especially after the
    // first full new-frame hit.
    var old_return = glitch * (1.0 - smoothstep(0.94, 1.0, reveal));
    old_return *= 0.18 + 0.52 * (1.0 - abs(local_reveal - 0.5) * 2.0);
    rgb = mix(rgb, old_clip.rgb, old_return * params.ghost_amount);

    let lines = sin((uv.y + f * 0.017) * 1080.0);
    rgb += lines * params.scanline * glitch;

    let exposure_pulse = (hash12(vec2f(f, 12.4)) - 0.35) * 0.10 * glitch;
    rgb += exposure_pulse;

    return vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), color.a);
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let uv = gpufx_uv(id);
    // Exact clips at both ends, whatever the formula rounds to.
    if (params.progress <= 0.0) { gpufx_write(id, textureSampleLevel(first, smp, uv, 0.0)); return; }
    if (params.progress >= 1.0) { gpufx_write(id, textureSampleLevel(second, smp, uv, 0.0)); return; }
    gpufx_write(id, transition(vec2f(uv.x, 1.0 - uv.y), params.progress));
}
