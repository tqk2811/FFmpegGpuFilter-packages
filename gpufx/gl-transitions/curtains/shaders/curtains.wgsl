// Port of Curtains.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Curtains.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let lag = params.sway * (1.0 - uv.y);
    let p = progress * (1.0 - lag * (1.0 - progress));
    let open = mix(p, p * p * (3.0 - 2.0 * p), 0.75);
    // Each curtain hangs from its outer edge, gathers to the bunch width, then leaves the frame.
    let edge = -params.bunch * open * open;
    let w = mix(0.5, params.bunch, open);
    let x = min(uv.x, 1.0 - uv.x) - edge;
    if (x >= w) {
        let to = to_color(uv);
        let shadow = 0.4 * exp((w - x) * 25.0) * clamp((edge + w) * 20.0, 0.0, 1.0);
        return vec4f(to.rgb * (1.0 - shadow * open), to.a);
    }
    let t = x / w;
    // Pleats: the fabric bunches up where cos(a) > 0 and is stretched elsewhere.
    let n = max(1.0, floor(params.folds * min(ratio, 1.0) + 0.5));
    let a = 2.0 * PI * n * t;
    let f = 1.0 - (1.0 - open) * (1.0 - open) * (1.0 - open);
    let gather = 0.92 * f;
    let s = 0.5 * (t + gather * sin(a) / (2.0 * PI * n));
    let left = uv.x < 0.5;
    let c = from_color(vec2f(select(1.0 - s, s, left), uv.y));
    let slope = 3.0 * gather * cos(a) * select(-1.0, 1.0, left);
    let diffuse = (1.0 + 0.5 * slope) / sqrt(1.25 * (1.0 + slope * slope));
    let crease = 0.5 + 0.5 * sin(a);
    let light = mix(1.0, diffuse * (1.0 - 0.6 * crease * crease), params.shading * f);
    return vec4f(c.rgb * light, c.a);
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
