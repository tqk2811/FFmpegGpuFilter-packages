// Port of Tunnel.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Tunnel.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn rotate(v: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * v.x - s * v.y, s * v.x + c * v.y);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let aspect = vec2f(globals.size.x / globals.size.y, 1.0);
    let c = (uv - 0.5) * aspect;
    let r = length(c);
    // A tube as wide as the corners runs from the camera to an end wall at depth `far`;
    // the first clip is projected onto it from the starting point of view. The camera
    // flies to one unit before the end wall, where the second clip hangs.
    let big_r = length(0.5 * aspect);
    let far = 1.0 + params.speed;
    // The distance to the end wall shrinks geometrically, so the end grows evenly.
    let e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.7);
    let d = pow(far, 1.0 - e);
    let t = far - d;
    let k = select(big_r / (big_r + t * r), d / far, r * d < big_r);
    let a = params.twist * min(t * r / big_r, t / d);
    var walls = from_color(0.5 + rotate(c * k, a) / aspect);
    walls = vec4f(walls.rgb * (0.4 + 0.6 * sqrt(k)), walls.a);
    let open = smoothstep(0.0, 0.6, progress);
    let q = 0.5 + (uv - 0.5) * d / max(open, 1e-4);
    let inside = step(vec2f(0.0), q) * step(q, vec2f(1.0));
    return mix(walls, to_color(q), inside.x * inside.y * step(r * d, big_r));
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
