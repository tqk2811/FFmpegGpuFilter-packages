// Port of StripDatamoshGlitch.glsl from gl-transitions (author: bread, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StripDatamoshGlitch.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

var<private> g_progress: f32;

fn hash1(n: f32) -> f32 {
    return fract(sin(n) * 43758.5453123);
}

fn hash2(p: vec2f) -> f32 {
    return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453123);
}

fn sat(v: f32) -> f32 { return clamp(v, 0.0, 1.0); }

fn burst() -> f32 {
    return pow(max(0.0, sin(g_progress * PI)), 0.42) * params.strength;
}

fn safe_uv(uv: vec2f) -> vec2f {
    return clamp(uv, vec2f(0.0), vec2f(1.0));
}

fn stripe_y(uv: vec2f, density: f32, seed: f32, min_width: f32, max_width: f32) -> f32 {
    let y = uv.y * density + seed * 0.137;
    let id = floor(y);
    let f = fract(y);
    let c = hash2(vec2f(id, seed));
    let w = mix(min_width, max_width, hash2(vec2f(id + 9.17, seed + 2.31)));
    return 1.0 - smoothstep(w, w + 0.018, abs(f - c));
}

fn stripe_x(uv: vec2f, density: f32, seed: f32, min_width: f32, max_width: f32) -> f32 {
    let x = uv.x * density + seed * 0.091;
    let id = floor(x);
    let f = fract(x);
    let c = hash2(vec2f(id, seed + 41.0));
    let w = mix(min_width, max_width, hash2(vec2f(id + 4.7, seed + 8.9)));
    return 1.0 - smoothstep(w, w + 0.012, abs(f - c));
}

fn broken_gate(uv: vec2f, row: f32, rnd: f32, frame: f32) -> f32 {
    let segs = mix(1.0, 9.0, hash2(vec2f(row, frame + 44.0)));
    let seg = floor(uv.x * segs);
    return step(0.16, hash2(vec2f(seg, row + frame * 3.0 + rnd)));
}

fn horizontal_mask(uv: vec2f, frame: f32) -> f32 {
    let bars = params.horizontal_bars;
    let r1 = floor((uv.y + hash1(frame) * 0.031) * bars * 0.38);
    let r2 = floor((uv.y + hash1(frame + 2.0) * 0.013) * bars);
    let r3 = floor((uv.y + hash1(frame + 7.0) * 0.006) * bars * 3.4);

    var thick = stripe_y(uv, bars * 0.38, frame + 1.0, 0.035, 0.22);
    var mid = stripe_y(uv, bars, frame + 4.0, 0.014, 0.11);
    var hair = stripe_y(uv, bars * 3.4, frame + 9.0, 0.004, 0.035);

    thick *= step(0.42, hash2(vec2f(r1, frame + 10.0)));
    mid *= step(0.48, hash2(vec2f(r2, frame + 20.0)));
    hair *= step(0.62, hash2(vec2f(r3, frame + 30.0)));

    thick *= broken_gate(uv, r1, hash2(vec2f(r1, frame)), frame);
    mid *= broken_gate(uv, r2, hash2(vec2f(r2, frame)), frame + 3.0);

    return sat(max(thick, max(mid, hair)));
}

fn vertical_mask(uv: vec2f, frame: f32) -> f32 {
    let col = floor((uv.x + hash1(frame + 12.0) * 0.017) * params.vertical_slits);
    var slit = stripe_x(uv, params.vertical_slits, frame + 13.0, 0.01, 0.075);
    slit *= step(0.66, hash2(vec2f(col, frame + 19.0)));
    return sat(slit);
}

fn chroma_from(uv0: vec2f, s: vec2f) -> vec4f {
    let uv = safe_uv(uv0);
    let center = from_color(uv);
    return vec4f(from_color(safe_uv(uv + s)).r, center.g, from_color(safe_uv(uv - s)).b, center.a);
}

fn chroma_to(uv0: vec2f, s: vec2f) -> vec4f {
    let uv = safe_uv(uv0);
    let center = to_color(uv);
    return vec4f(to_color(safe_uv(uv - s)).r, center.g, to_color(safe_uv(uv + s)).b, center.a);
}

fn distort_uv(uv: vec2f, dir: f32, b: f32, h: f32, v: f32, frame: f32) -> vec2f {
    let row = floor(uv.y * params.horizontal_bars);
    let col = floor(uv.x * params.vertical_slits);

    let row_rnd = hash2(vec2f(row, frame));
    let col_rnd = hash2(vec2f(col, frame + 27.0));

    var x_tear = (row_rnd - 0.5) * 2.0 * params.tear * b * h;
    x_tear += sin(uv.y * 120.0 + g_progress * 95.0) * 0.006 * b;

    let y_drag = (col_rnd - 0.5) * 0.13 * b * v;
    let micro = (hash2(vec2f(row, col + frame)) - 0.5) * 0.018 * b * max(h, v);

    return uv + vec2f(x_tear * dir + micro, y_drag);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    g_progress = progress;
    let ratio = globals.size.x / globals.size.y;
    let b = burst();
    let frame = floor(progress * 30.0);

    let h = horizontal_mask(uv, frame);
    let v = vertical_mask(uv, frame);
    let glitch = sat(max(h, v * 0.75));

    let row = floor(uv.y * params.horizontal_bars);
    let row_rnd = hash2(vec2f(row, frame + 5.0));

    let band_delay = (row_rnd - 0.5) * 0.30 * h;
    let reveal = smoothstep(0.18, 0.84, progress + band_delay);

    let split = vec2f(params.chroma * b * (1.0 + 1.7 * glitch), params.chroma * 0.22 * b * v);

    let from_uv = distort_uv(uv, 1.0, b, h, v, frame);
    let to_uv = distort_uv(uv, -1.0, b, h, v, frame);

    var color = mix(chroma_from(from_uv, split), chroma_to(to_uv, split), reveal);

    var smear_uv = uv;
    smear_uv.x += (row_rnd - 0.5) * 0.46 * b * h;
    smear_uv.y += (hash2(vec2f(row, frame + 31.0)) - 0.5) * 0.045 * b * h;

    let slice_reveal = smoothstep(0.28, 0.78, progress + (row_rnd - 0.5) * 0.22);
    let slice_color = mix(
        chroma_from(smear_uv, split * 1.65),
        chroma_to(smear_uv - vec2f((row_rnd - 0.5) * 0.18 * b, 0.0), split * 1.65),
        slice_reveal);

    color = mix(color, slice_color, h * b * params.residue);

    var hair_line = stripe_y(uv, 190.0, frame + 55.0, 0.002, 0.012);
    hair_line *= step(0.70, hash2(vec2f(floor(uv.y * 190.0), frame + 56.0)));
    var rgb = color.rgb + vec3f(0.72, 0.90, 1.0) * hair_line * b * 0.28;

    let scan = 0.5 + 0.5 * sin(uv.y * 980.0 + progress * 130.0);
    rgb *= 1.0 - params.scan_amount * b * scan;

    let n_cell = floor(uv * vec2f(360.0 * ratio, 210.0));
    let n = hash2(n_cell + vec2f(frame * 7.0, frame * 13.0));
    rgb += (n - 0.5) * params.noise_amount * b * (0.55 + glitch);

    let luma = dot(rgb, vec3f(0.299, 0.587, 0.114));
    rgb = mix(rgb, vec3f(luma), 0.18 * b * glitch);

    let strobe = step(0.78, hash2(vec2f(frame, 3.14))) * pow(b, 1.65);
    rgb += vec3f(strobe * params.flash_amount);

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
