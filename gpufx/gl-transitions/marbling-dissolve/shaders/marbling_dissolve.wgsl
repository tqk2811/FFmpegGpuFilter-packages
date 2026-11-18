// Port of MarblingDissolve.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MarblingDissolve.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// How sharply the picture is pulled into a point right at a tooth, relative to the spacing of the teeth.
const CUSP: f32 = 0.12;
// Teeth of the fine comb pulled across, per frame height.
const COMB: f32 = 9.0;

// Folds coordinates back into the frame, so a dragged picture never shows its clamped edges.
fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - (v - 2.0 * floor(v / 2.0)));
}

// Pull of a tooth on the bath at distance t (in tooth spacings, 0..1): 1 at the tooth, 0 at the
// next one, pointed at the tooth like ink dragged by a needle.
fn drag(t: f32) -> f32 {
    let far = CUSP / (1.0 + CUSP);
    return (CUSP / (t + CUSP) - far) / (1.0 - far);
}

fn ease(x0: f32) -> f32 {
    let x = clamp(x0, 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

// Where the bath at p (in frame heights) was before the rake and the comb went through it.
fn unrake(p0: vec2f, rake: f32, comb: f32, ratio: f32) -> vec2f {
    var p = p0;
    // Fine comb pulled across the frame, all teeth going the same way: feathers.
    let c = p.y * COMB;
    let t = fract(c);
    p.x -= comb * drag(2.0 * min(t, 1.0 - t));
    // Rake pulled up and down, its teeth going in turns one way and the other: zigzags spaced
    // along the longer side of the frame, with a tooth in the middle.
    let s = max(ratio, 1.0) / max(params.tines, 1.0);
    let k = (p.x - 0.5 * ratio) / s;
    let u = fract(k);
    let fk = floor(k);
    let side = select(-1.0, 1.0, fk - 2.0 * floor(fk / 2.0) < 0.5);
    p.y -= rake * side * (drag(u) - drag(1.0 - u));
    return p;
}

fn band_phase(q: vec2f) -> f32 {
    return q.y * params.bands + 0.35 * sin(q.x * 2.3 + 1.0) + 0.2 * sin(q.x * 5.1 - q.y * 3.0);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let pull = params.pull;
    let rake = pull * ease(progress / 0.35) * ease((1.0 - progress) / 0.35);
    let comb = 0.6 * pull * ease((progress - 0.15) / 0.3) * ease((0.85 - progress) / 0.3);
    let p = vec2f(uv.x * ratio, uv.y);
    let q = unrake(p, rake, comb, ratio);
    // Phase gradient on screen, to antialias the bands where the rake squeezed them.
    let e = 0.001;
    let ph = band_phase(q);
    let gx = band_phase(unrake(p + vec2f(e, 0.0), rake, comb, ratio)) - ph;
    let gy = band_phase(unrake(p + vec2f(0.0, e), rake, comb, ratio)) - ph;
    let aa = max(length(vec2f(gx, gy)), 0.002);
    let cover = ease((progress - 0.08) / 0.84);
    // Half width of the bands: from just below 0 to just above 0.5, so they are exactly empty then full.
    let w = cover * (0.5 + 2.0 * aa) - aa;
    let d = abs(fract(ph) - 0.5); // 0 in the middle of a band, 0.5 between two
    let m = 1.0 - smoothstep(w - aa, w + aa, d);
    let suv = mirror(vec2f(q.x / ratio, q.y));
    let col = mix(from_color(suv), to_color(suv), m);
    let line = 1.0 - smoothstep(0.0, 2.5 * aa + 0.02, abs(d - w));
    let show = params.veins * 4.0 * cover * (1.0 - cover); // exactly 0 when the bands are empty or full
    return vec4f(col.rgb * (1.0 - 0.6 * show * line), col.a);
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
