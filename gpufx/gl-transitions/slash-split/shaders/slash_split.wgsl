// Port of SlashSplit.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SlashSplit.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Part of the transition during which the blade crosses the frame.
const CUT: f32 = 0.18;
const EDGE: f32 = 0.0015;
const SHADOW_OFFSET: vec2f = vec2f(0.015, -0.022);
const SHADOW_BLUR: f32 = 0.035;

fn ratio() -> f32 { return globals.size.x / globals.size.y; }

// Signed distance (aspect units) to the frame rectangle centered on 0, negative inside.
fn box_distance(q: vec2f) -> f32 {
    let d = abs(q) - 0.5 * vec2f(ratio(), 1.0);
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

// One half of the first clip, moved by v; s = 1 for the half above the cut, -1 below.
// Returns the clip point of screen point q (xy) and a signed distance to the half (z, negative inside).
fn piece(q: vec2f, v: vec2f, n: vec2f, s: f32) -> vec3f {
    let y = q - v;
    return vec3f(y, max(box_distance(y), -s * dot(y, n)) - 0.5 * EDGE);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let p = progress;
    let r = ratio();
    let a = radians(params.angle);
    let tt = vec2f(cos(a), sin(a));
    let nn = vec2f(-tt.y, tt.x);
    let q = (uv - 0.5) * vec2f(r, 1.0);
    let d = dot(q, nn);
    let along = dot(q, tt);

    let t = clamp((p - 0.8 * CUT) / (1.0 - 0.8 * CUT), 0.0, 1.0);
    let open = params.separation * (1.0 - pow(1.0 - t, 3.0));
    let margin = length(SHADOW_OFFSET) + SHADOW_BLUR + 2.0 * EDGE;
    let exit_x = (r + params.separation + margin) / max(abs(tt.x), 1e-3);
    let exit_y = (1.0 + params.separation + margin) / max(abs(tt.y), 1e-3);
    let slide = min(exit_x, exit_y) * t * t * (1.5 - 0.5 * t);
    let v_up = tt * slide + nn * open;

    let to = to_color(uv);
    let sq = q - SHADOW_OFFSET;
    let sd_up = piece(sq, v_up, nn, 1.0).z;
    let sd_down = piece(sq, -v_up, nn, -1.0).z;
    let sh = params.shadow.a * smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(-0.5 * SHADOW_BLUR, SHADOW_BLUR, min(sd_up, sd_down)));
    var c = vec4f(mix(to.rgb, params.shadow.rgb, sh), to.a);

    let reach = 0.5 * length(vec2f(r, 1.0)) + 0.1;
    let k = clamp(p / CUT, 0.0, 1.0);
    let head = mix(-reach, reach, 1.0 - (1.0 - k) * (1.0 - k));
    let behind = head - along;
    let drawn = clamp(0.5 + behind / EDGE, 0.0, 1.0);

    let flash = params.flash;
    let rim = flash.a * smoothstep(0.0, CUT, p) * (1.0 - 0.6 * t) * drawn;
    for (var i = 0; i < 2; i++) {
        let s = select(-1.0, 1.0, i == 0);
        let h = piece(q, s * v_up, nn, s);
        let cover = clamp(0.5 - h.z / EDGE, 0.0, 1.0);
        var col = from_color(clamp(h.xy / vec2f(r, 1.0) + 0.5, vec2f(0.0), vec2f(1.0)));
        let e = max(s * dot(h.xy, nn), 0.0);
        col = vec4f(mix(col.rgb, flash.rgb, rim * exp(-e / 0.004) * col.a), col.a);
        c = mix(c, col, cover);
    }

    let tail = drawn * (0.35 + 0.65 * exp(-max(behind, 0.0) * 4.0));
    let env = smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(CUT, CUT + 0.12, p));
    let core = exp(-abs(d) / 0.0025) + 0.35 * exp(-abs(d) / 0.02);
    let spark = exp(-length(vec2f(behind, d)) / 0.03) * (1.0 - k);
    let glow = flash.a * env * (core * tail + spark);
    let burst = flash.a * 0.25 * smoothstep(0.6 * CUT, CUT, p) * (1.0 - smoothstep(CUT, CUT + 0.15, p));
    c = vec4f(mix(c.rgb, flash.rgb, burst * c.a) + flash.rgb * glow * c.a, c.a);
    return c;
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
