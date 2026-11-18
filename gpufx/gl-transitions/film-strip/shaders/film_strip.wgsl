// Port of FilmStrip.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FilmStrip.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const FRAME_LINE: f32 = 0.08;
const HOLES: f32 = 4.0;
const SAMPLES: i32 = 16;

fn dither(cell: vec2f) -> f32 {
    return fract(52.9829189 * fract(dot(cell, vec2f(0.06711056, 0.00583715))));
}

// The film at (x, y): x across it (0 to 1 over the picture), y along it from the start of frame
// number base, in frame heights; holes fades the sprocket holes in.
fn film(x: f32, y: f32, base: f32, n: f32, aa: f32, hole_x: f32, hole_size: vec2f, holes: f32, ratio: f32) -> vec4f {
    let film_color = params.film_color;
    let pitch = 1.0 + FRAME_LINE;
    let jy = floor(y / pitch);
    let j = base + jy;
    let fy = y - jy * pitch;
    var c = film_color;
    if (x >= 0.0 && x <= 1.0 && fy <= 1.0) {
        let q = vec2f(x, fy);
        if (j < n) { c = from_color(q); } else { c = to_color(q); }
    }
    // Soft edges for the picture during the slip (none at rest, where it fills the frame).
    let in_pic = min(min(x, 1.0 - x) * ratio, min(fy, 1.0 - fy));
    c = mix(film_color, c, clamp(in_pic / aa + 0.5, 0.0, 1.0));
    let hp = pitch / HOLES;
    let hy = y - hp * floor(y / hp) - 0.5 * hp;
    let hx = (abs(x - 0.5) - hole_x) * ratio;
    let dd = abs(vec2f(hx, hy)) - hole_size + 0.3 * hole_size.x;
    let sd = length(max(dd, vec2f(0.0))) + min(max(dd.x, dd.y), 0.0) - 0.3 * hole_size.x;
    return mix(c, params.hole_color, clamp(0.5 - sd / aa, 0.0, 1.0) * holes);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shrink = params.shrink;
    let n = max(f32(params.frames), 1.0);
    let pitch = 1.0 + FRAME_LINE;
    let p = progress;
    let env = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.7, 1.0, p));
    let k = 1.0 - shrink * env;
    let x0 = clamp((p - 0.15) / 0.7, 0.0, 1.0);
    let slip = x0 * x0 * x0 * (x0 * (x0 * 6.0 - 15.0) + 10.0);
    let speed = 30.0 * x0 * x0 * (1.0 - x0) * (1.0 - x0) / 0.7; // d(slip)/d(progress), up to ~2.7
    let wob = params.weave * env;
    // (the weave stays within the film's margin)
    let dx = wob * smoothstep(0.0, 0.1, shrink) * (0.006 * sin(p * 47.0) + 0.004 * sin(p * 113.0 + 1.3));
    let dy = wob * 0.012 * sin(p * 71.0 + 0.4) * (1.0 - speed / 2.7);

    let frame_slip = slip * n;
    let base = floor(frame_slip);
    let x = (uv.x - 0.5) / k + 0.5 + dx;
    let y = (uv.y - 0.5) / k + 0.5 + dy + (frame_slip - base) * pitch;
    // Antialiasing width, in frame heights: none at rest or without margin.
    let aa = 0.002 * min(1.0, 10.0 * env) * min(1.0, 20.0 * shrink) + 1e-4;
    let margin = 0.5 * shrink / max(1.0 - shrink, 0.01);
    let hole_x = 0.5 + 0.5 * margin;
    let hole_size = vec2f(0.28 * margin * ratio, 0.11 * pitch / HOLES);
    let holes = smoothstep(0.0, 0.02, margin);

    // Motion blur along the strip, dithered to hide the steps.
    let len = params.blur * 0.06 * speed * n;
    var color = vec4f(0.0);
    if (len < 1e-5) {
        color = film(x, y, base, n, aa, hole_x, hole_size, holes, ratio);
    } else {
        // Averaged with premultiplied colors, so transparent parts do not darken the others.
        let jitter = dither(floor(uv * vec2f(ratio, 1.0) * 540.0));
        for (var i = 0; i < SAMPLES; i++) {
            let t = (f32(i) + jitter) / f32(SAMPLES) - 0.5;
            let c = film(x, y + t * len, base, n, aa, hole_x, hole_size, holes, ratio);
            color += vec4f(c.rgb * c.a, c.a);
        }
        color /= f32(SAMPLES);
        if (color.a > 0.0) { color = vec4f(color.rgb / color.a, color.a); } else { color = vec4f(0.0, 0.0, 0.0, color.a); }
    }
    return vec4f(color.rgb * (1.0 - 0.08 * wob * (0.5 + 0.5 * sin(p * 157.0))), color.a);
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
