// Port of InsetWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InsetWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const AA: f32 = 0.001;

fn premultiplied(c: vec4f) -> vec4f { return vec4f(c.rgb * c.a, c.a); }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let reverse = params.reverse != 0u;
    let a = from_color(uv);
    let b = to_color(uv);
    // The anchor option is given y down.
    let an = clamp(vec2f(params.anchor.x, 1.0 - params.anchor.y), vec2f(0.0), vec2f(1.0));
    let sq = vec2f(ratio, 1.0);
    // The rectangle reaches every far side of the frame at once; measured in square pixels.
    let ext = max(an, 1.0 - an) * sq;
    let d = abs(uv - an) * sq;
    let s = max(params.smoothness, AA);
    let bw = max(params.border_width, 0.0);
    let t = select(progress, 1.0 - progress, reverse);
    let p = mix(t, t * t * (3.0 - 2.0 * t), 0.3);
    let size = p * ext + mix(-(bw + s), s, p);
    // Signed distance to the rectangle's edge, square-cornered, < 0 inside.
    let e = max(d.x - size.x, d.y - size.y);
    let inside = select(b, a, reverse);
    var c = premultiplied(select(a, b, reverse));
    if (bw > 0.0) {
        // Laid over the picture outside the rectangle, so a translucent border tints it.
        let m = 1.0 - smoothstep(bw - s, bw + s, e);
        c = premultiplied(params.border_color) * m + c * (1.0 - params.border_color.a * m);
    }
    c = mix(c, premultiplied(inside), 1.0 - smoothstep(-s, s, e));
    return select(vec4f(0.0), vec4f(c.rgb / c.a, c.a), c.a > 0.0);
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
