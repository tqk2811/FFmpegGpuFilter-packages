// Port of LayoutGrid.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/LayoutGrid.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PANELS: i32 = 6;
// The gutters open over [0, OPEN] and close over [1 - OPEN, 1].
const OPEN: f32 = 0.28;
// The first push starts at START, the last one ends at 1 - START.
const START: f32 = 0.1;
const EDGE: f32 = 0.0025;

// Panel i of the layout: xy its bottom-left corner, zw its top-right corner, in uv; reading order.
fn panel_rect(i: i32, portrait: bool) -> vec4f {
    if (portrait) {
        switch (i) {
            case 0: { return vec4f(0.0, 0.68, 0.62, 1.0); }
            case 1: { return vec4f(0.62, 0.68, 1.0, 1.0); }
            case 2: { return vec4f(0.0, 0.36, 1.0, 0.68); }
            case 3: { return vec4f(0.0, 0.0, 0.46, 0.36); }
            case 4: { return vec4f(0.46, 0.17, 1.0, 0.36); }
            default: { return vec4f(0.46, 0.0, 1.0, 0.17); }
        }
    }
    switch (i) {
        case 0: { return vec4f(0.0, 0.42, 0.4, 1.0); }
        case 1: { return vec4f(0.4, 0.64, 1.0, 1.0); }
        case 2: { return vec4f(0.4, 0.0, 0.7, 0.64); }
        case 3: { return vec4f(0.7, 0.32, 1.0, 0.64); }
        case 4: { return vec4f(0.7, 0.0, 1.0, 0.32); }
        default: { return vec4f(0.0, 0.0, 0.4, 0.42); }
    }
}

// Direction the first clip of panel i is pushed toward (the second enters from the opposite side).
fn panel_dir(i: i32, portrait: bool) -> vec2f {
    if (portrait) {
        switch (i) {
            case 0: { return vec2f(1.0, 0.0); }
            case 1: { return vec2f(0.0, -1.0); }
            case 2: { return vec2f(-1.0, 0.0); }
            case 3: { return vec2f(0.0, 1.0); }
            case 4: { return vec2f(1.0, 0.0); }
            default: { return vec2f(-1.0, 0.0); }
        }
    }
    switch (i) {
        case 0: { return vec2f(0.0, -1.0); }
        case 1: { return vec2f(-1.0, 0.0); }
        case 2: { return vec2f(0.0, 1.0); }
        case 3: { return vec2f(1.0, 0.0); }
        case 4: { return vec2f(-1.0, 0.0); }
        default: { return vec2f(1.0, 0.0); }
    }
}

fn ease_in_out(t: f32) -> f32 {
    return select(1.0 - 4.0 * (1.0 - t) * (1.0 - t) * (1.0 - t), 4.0 * t * t * t, t < 0.5);
}

// Coverage of [lo, hi] at x with antialiased ends: adjacent intervals add up to 1.
fn span1(x: f32, lo: f32, hi: f32, aa: f32) -> f32 {
    return smoothstep(lo - aa, lo + aa, x) * (1.0 - smoothstep(hi - aa, hi + aa, x));
}

fn box_dist(p: vec2f, lo: vec2f, hi: vec2f) -> f32 {
    let d = abs(p - 0.5 * (lo + hi)) - 0.5 * (hi - lo);
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shadow = params.shadow;
    let portrait = ratio < 1.0;
    let aspect = vec2f(ratio, 1.0) / min(ratio, 1.0);
    let p = uv * aspect;
    let open = smoothstep(0.0, OPEN, progress) * (1.0 - smoothstep(1.0 - OPEN, 1.0, progress));
    let g = params.gutter * open;
    let ov = clamp(params.overlap, 0.0, 0.9);
    let span = (1.0 - 2.0 * START) / (1.0 + f32(PANELS - 1) * (1.0 - ov));
    var color = vec4f(0.0);
    var cover = 0.0;
    var shade = 0.0;
    for (var i = 0; i < PANELS; i++) {
        let r = panel_rect(i, portrait);
        var lo = r.xy * aspect + 0.5 * g;
        var hi = r.zw * aspect - 0.5 * g;
        // No gutter along the frame's border: the panels there run past it.
        lo = mix(lo, vec2f(-1.0), step(r.xy, vec2f(0.0)));
        hi = mix(hi, aspect + 1.0, step(vec2f(1.0), r.zw));
        let t = clamp((progress - START - f32(i) * span * (1.0 - ov)) / span, 0.0, 1.0);
        let lift = 1.0 + 1.2 * sin(3.141592653589793 * t);
        let sd = box_dist(p - vec2f(0.2, -0.35) * g * lift, lo, hi);
        shade = max(shade, (1.0 - smoothstep(-0.2 * g, 0.6 * g * lift + 1e-4, sd)) / sqrt(lift));
        // Separable coverage, so the panels add up to exactly 1 once the gutters close.
        let inside = span1(p.x, lo.x, hi.x, EDGE) * span1(p.y, lo.y, hi.y, EDGE);
        if (inside > 0.0) {
            let dir = panel_dir(i, portrait);
            var c: vec4f;
            if (t <= 0.0) {
                c = from_color(uv);
            } else if (t >= 1.0) {
                c = to_color(uv);
            } else {
                let e = ease_in_out(t);
                // A train slides along dir through the panel: first clip, accent band, second clip.
                let len = abs(dot(r.zw - r.xy, dir));
                let w = params.band * len;
                let q = uv - dir * e * (len + w);
                let a = dot(q - select(r.xy, r.zw, dir.x + dir.y < 0.0), dir);
                let af = a * abs(dot(aspect, dir));
                let wf = w * abs(dot(aspect, dir));
                let from_w = smoothstep(-EDGE, 0.0, af);
                let to_w = 1.0 - smoothstep(-wf, -wf + EDGE, af);
                let band_shade = 1.0 - shadow * 0.5 * (1.0 - smoothstep(-wf, -wf + 0.35 * wf + 1e-4, af));
                let b = vec4f(params.accent.rgb * band_shade, params.accent.a);
                c = mix(b, from_color(clamp(q, r.xy, r.zw)), from_w);
                c = mix(c, to_color(clamp(q + dir * (len + w), r.xy, r.zw)), to_w);
            }
            color += c * inside;
            cover += inside;
        }
    }
    color /= max(cover, 1.0);
    cover = min(cover, 1.0);
    let bg = vec4f(params.paper.rgb * (1.0 - shadow * shade * open), params.paper.a);
    return color + bg * (1.0 - cover);
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
