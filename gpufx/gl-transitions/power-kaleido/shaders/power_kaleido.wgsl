// Port of PowerKaleido.glsl from gl-transitions (author: Boundless, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PowerKaleido.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265358979;
// The mirror angle: 120 degrees.
const DEG: f32 = 120.0 / 180.0 * 3.14159265358979;

fn refl(p: vec2f, o: vec2f, n: vec2f) -> vec2f { return 2.0 * o + 2.0 * n * dot(p - o, n) - p; }

fn rot(p: vec2f, o: vec2f, a: f32) -> vec2f {
    let s = sin(a);
    let c = cos(a);
    return o + mat2x2f(c, -s, s, c) * (p - o);
}

fn transition(uv_in: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let dist = params.scale / 10.0;
    let speed = params.speed;
    var uv = uv_in - 0.5;
    uv.x *= ratio;
    uv *= params.z;
    uv = rot(uv, vec2f(0.0), progress * speed);
    for (var iter = 0; iter < 10; iter++) {
        for (var j = 0; j < 3; j++) {
            let i = f32(j) * DEG;
            let ts = sign(asin(clamp(cos(i), -1.0, 1.0))) == 1.0;
            let lhs = uv.y - dist * cos(i);
            let rhs = tan(i) * (uv.x + dist * sin(i));
            if ((ts && lhs > rhs) || (!ts && lhs < rhs)) {
                uv = refl(vec2f(uv.x + sin(i) * dist * 2.0, uv.y - cos(i) * dist * 2.0), vec2f(0.0), vec2f(cos(i), sin(i)));
            }
        }
    }
    uv += 0.5;
    uv = rot(uv, vec2f(0.5), progress * -speed);
    uv -= 0.5;
    uv.x /= ratio;
    uv += 0.5;
    uv = 2.0 * abs(uv / 2.0 - floor(uv / 2.0 + 0.5));
    let uv_mix = mix(uv, uv_in, cos(progress * PI * 2.0) / 2.0 + 0.5);
    return mix(from_color(uv_mix), to_color(uv_mix), cos((progress - 1.0) * PI) / 2.0 + 0.5);
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
