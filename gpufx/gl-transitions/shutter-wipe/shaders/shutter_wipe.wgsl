// Port of ShutterWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ShutterWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

// Spacing of the blades in their stacks, and how far the stacks rest outside the frame, in frame heights.
const STACK: f32 = 0.016;
const REST: f32 = 0.05;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let color = params.color;
    let n = clamp(f32(params.blades), 3.0, 10.0);
    // Tall enough to still overlap, past their blurred edges, when they are spread the most.
    let h = 1.7 / n + 0.02;
    let pile = (n - 1.0) * STACK;
    // The bottoms of the blades run from a stack above the frame to a stack below it.
    let travel = 1.0 + 2.0 * REST + h + pile;
    let t = clamp((progress - vec2f(0.0, 0.3)) / 0.7, vec2f(0.0), vec2f(1.0));
    let pos = 1.0 + REST + vec2f(0.0, pile) - travel * t * t * (3.0 - 2.0 * t);
    let vel = travel * 6.0 * t * (1.0 - t) / 0.7;
    let x = (uv.x - 0.5) * ratio;
    var col = select(to_color(uv), from_color(uv), progress < 0.5);
    // Painted from the lowest blade to the highest, each one over the top of the one below it.
    for (var i = 0; i < 10; i++) {
        let k = f32(i) / (n - 1.0);
        if (k < 1.0001) {
            let v = mix(vel.x, vel.y, k);
            let d = uv.y - mix(pos.x, pos.y, k) + params.tilt * 0.1 * v * x;
            let aa = 0.002 + 0.005 * v;
            let sh = (1.0 - smoothstep(0.0, 0.03 + 0.012 * v, -d)) * (1.0 - smoothstep(-aa, aa, d));
            col = vec4f(col.rgb * (1.0 - 0.65 * color.a * sh * sh), col.a);
            let l = clamp(d / h, 0.0, 1.0);
            let lip = smoothstep(0.003, 0.007, d) * (1.0 - smoothstep(0.007, 0.014, d));
            let s = (uv.y - d - 0.55 + 0.3 * x) * 2.5;
            let sheen = 0.3 * exp(-s * s) * (1.0 - l) * (1.0 - l);
            var metal = color.rgb * (1.3 - 0.75 * l) + (0.25 * lip + sheen) * (0.6 + 0.4 * color.rgb) * color.a;
            metal *= 0.4 + 0.6 * smoothstep(0.0, 0.005, d);
            let cover = smoothstep(-aa, aa, d) * (1.0 - smoothstep(h - aa, h + aa, d));
            col = mix(col, vec4f(clamp(metal, vec3f(0.0), vec3f(1.0)), color.a), cover);
        }
    }
    let g = params.gate * smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
    let c = abs(uv - 0.5) * vec2f(ratio, 1.0) - vec2f(0.5 * ratio, 0.5) + 1.5 * g;
    let e = length(max(c, vec2f(0.0))) + min(max(c.x, c.y), 0.0) - 0.5 * g;
    let on = smoothstep(0.0, 0.002, params.gate) * smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.96, 1.0, progress));
    col = vec4f(col.rgb * (1.0 - 0.5 * color.a * on * smoothstep(-0.4 * g - 0.001, 0.0, e)), col.a);
    let housing = min(color.rgb * (1.5 - smoothstep(0.0, 0.2 * g + 0.001, e)), vec3f(1.0));
    return mix(col, vec4f(housing, color.a), on * smoothstep(-0.002, 0.002, e));
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
