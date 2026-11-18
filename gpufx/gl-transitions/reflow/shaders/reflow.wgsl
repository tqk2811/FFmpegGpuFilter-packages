// Port of Reflow.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Reflow.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const EDGE: f32 = 0.002;

fn ease(x: f32) -> f32 {
    return select(1.0 - 4.0 * (1.0 - x) * (1.0 - x) * (1.0 - x), 4.0 * x * x * x, x < 0.5);
}

// One clip laid out as a stream of rows in a box [x0, x0 + w]; a narrow space separates its rows like words.
fn box(uv: vec2f, x0: f32, w: f32, env: f32, incoming: bool) -> vec4f {
    let n = max(f32(params.lines), 1.0);
    let row = (1.0 - uv.y) * n;
    let line = floor(row);
    let yin = row - line;
    let space = 0.04 * env;
    let q = line * w + clamp(uv.x - x0, 0.0, w);
    var src = floor(q / (1.0 + space));
    var xin = q - src * (1.0 + space);
    // The second half of a space antialiases the start of the next row.
    if (xin > 1.0 + 0.5 * space) {
        src += 1.0;
        xin -= 1.0 + space;
    }
    let s = vec2f(clamp(xin, 0.0, 1.0), 1.0 - (src + yin) / n);
    var c = select(from_color(s), to_color(s), incoming);
    let lead = 0.06 * env;
    let d = min(yin, 1.0 - yin);
    // Masks are offset by one edge width so they stay exactly 1 where a gap has zero width.
    var ink = clamp((d - lead) / (EDGE * n) + 1.0, 0.0, 1.0);
    ink *= clamp(min(xin, 1.0 - xin) / EDGE + 1.0, 0.0, 1.0);
    let in_box = clamp(min(uv.x - x0, x0 + w - uv.x) / EDGE + 1.0, 0.0, 1.0);
    ink *= in_box;
    c = vec4f(c.rgb * (1.0 - 0.2 * env * (1.0 - smoothstep(0.0, 0.2, d))), c.a);
    // Each line casts a short shadow on the paper just below it.
    let below = select(yin - (1.0 - lead), yin + lead, yin < 0.5);
    var bg = params.paper;
    bg = vec4f(bg.rgb * (1.0 - 0.3 * env * in_box * step(0.0, below) * step(0.5, row) * exp(-below / 0.04)), bg.a);
    return mix(bg, c, ink);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let w = 1.0 - ease(progress);
    let env = 4.0 * w * (1.0 - w);
    let g = 0.012 * env;
    if (uv.x < w) { return box(uv, 0.0, w - g, env, false); }
    return box(uv, w + g, 1.0 - w - g, env, true);
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
