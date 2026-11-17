// Port of FallOver.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/FallOver.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let fall = progress * (0.25 + 0.75 * progress);
    let angle = 0.5 * PI * fall;
    let c = cos(angle);
    let s = sin(angle);
    // A camera in front of the middle goes down to the hinge level, so the picture ends edge-on.
    let dist = 1.0 / max(params.perspective, 0.01);
    let eye = vec3f(0.5 * ratio, 0.5 * c, -dist);
    let dir = vec3f(uv.x * ratio, uv.y, 0.0) - eye;
    let den = dir.z * c - dir.y * s;
    if (den > 0.0) {
        let t = (eye.y * s - eye.z * c) / den;
        let hit = eye + t * dir;
        let puv = vec2f(hit.x / ratio, hit.y * c + hit.z * s);
        if (t > 0.0 && puv.y > 0.0 && puv.y <= 1.0 && puv.x >= 0.0 && puv.x <= 1.0) {
            let col = from_color(puv);
            return vec4f(col.rgb * (1.0 - params.shading * s), col.a);
        }
    }
    return to_color(uv);
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
