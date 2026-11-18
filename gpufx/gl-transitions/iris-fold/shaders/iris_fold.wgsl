// Port of IrisFold.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/IrisFold.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.004;
// Strip-steps each strip takes to slide in, so a few slide at once.
const D: f32 = 1.8;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let aspect = vec2f(ratio, 1.0);
    let q = (uv - 0.5) * aspect;
    let R = 0.5 * length(aspect);
    let ns = clamp(f32(params.sides), 3.0, 6.0);
    let N = ns * clamp(f32(params.rounds), 2.0, 5.0);
    let L = N - ns;
    // The last round closes the hole in a quicker burst.
    let tt = pow(clamp(progress / 0.9, 0.0, 1.0), 0.85) * (L + 0.4 * (ns - 1.0) + D);
    let deco = params.shading * (1.0 - smoothstep(0.88, 1.0, progress));
    let w0 = 0.6 * R;
    let turn = 2.0 * PI / ns + params.twist;
    let rot = vec2f(cos(turn), sin(turn));
    var n = vec2f(cos(0.3), sin(0.3));
    var col = from_color(uv);
    let to = to_color(uv);
    for (var i = 0; i < 30; i++) {
        let k = f32(i);
        if (k >= N) { break; }
        let s = clamp((tt - min(k, L + 0.4 * (k - L))) / D, 0.0, 1.0);
        if (s <= 0.0) { break; }
        let lift = 1.0 - s;
        let e = 1.0 - lift * lift * lift;
        // The whole last round crosses the center so the strips surely cover the frame.
        let goal = mix(0.68 * R, -0.03, min((k + 1.0) / (L + 1.0), 1.0));
        let d = dot(q, n) - goal - (R + 0.06 - goal) * (1.0 - e);
        // The first round reaches past the frame; the others fade their outer edge out as they land.
        let landed = select(smoothstep(0.7, 1.0, s), 1.0, k < ns);
        let m = smoothstep(-AA, AA, d) * mix(1.0 - smoothstep(w0 - AA, w0 + AA, d), 1.0, landed);
        let reach = 0.025 + 0.03 * lift;
        let sh = (1.0 - smoothstep(0.0, reach, -d)) * step(d, 0.0) + (1.0 - landed) * (1.0 - smoothstep(0.0, 0.6 * reach, d - w0)) * step(w0, d);
        col = vec4f(col.rgb * (1.0 - (0.4 + 0.2 * lift) * deco * sh * sh), col.a);
        var b = to;
        b = vec4f(mix(b.rgb, vec3f(1.0), 0.35 * deco * b.a * exp(-max(d, 0.0) / 0.005)), b.a);
        let odd = select(0.5, 1.0, k - 2.0 * floor(k / 2.0) < 0.5);
        b = vec4f(b.rgb * (1.0 - deco * (0.12 * smoothstep(0.0, w0, d) * odd + 0.1 * lift)), b.a);
        col = mix(col, b, m);
        n = vec2f(n.x * rot.x - n.y * rot.y, n.x * rot.y + n.y * rot.x);
    }
    return col;
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
