// Port of UndulatingBurnOut.glsl from gl-transitions (author: pthrasher, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/UndulatingBurnOut.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const M_PI: f32 = 3.14159265358979323846;

fn quadratic_in_out(t: f32) -> f32 {
    let p = 2.0 * t * t;
    return select(-p + 4.0 * t - 1.0, p, t < 0.5);
}

fn gradient(r: f32, dist: f32) -> f32 {
    let sm = params.smoothness;
    let d = r - dist;
    return mix(smoothstep(-sm, 0.0, r - dist * (1.0 + sm)), -1.0 - step(0.005, d), step(-0.005, d) * step(d, 0.01));
}

fn wave(p: vec2f, center: vec2f, x: f32) -> f32 {
    let q = p - center;
    var degs = degrees(atan2(q.y, q.x)) + 180.0;
    degs = degs * (M_PI * 30.0) / 360.0;
    let magnitude = mix(0.02, 0.09, smoothstep(0.0, 1.0, x));
    let offset = mix(40.0, 30.0, smoothstep(0.0, 1.0, x));
    let pos = quadratic_in_out(sin(degs)) * magnitude * sin(x * offset);
    // The soft edge reaches `smoothness` beyond the radius and the burn band 0.005 inside it:
    // the radius starts below both so only the first clip shows at progress 0.
    return x - max(params.smoothness, 0.01) * (1.0 - smoothstep(0.0, 0.1, x)) + pos;
}

fn transition(p: vec2f, progress: f32) -> vec4f {
    // `center` is given y down.
    let center = vec2f(params.center.x, 1.0 - params.center.y);
    let m = gradient(wave(p, center, progress), distance(center, p));
    let cfrom = from_color(p);
    let cto = to_color(p);
    return mix(mix(cfrom, cto, m), mix(cfrom, params.color, 0.75), step(m, -2.0));
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
