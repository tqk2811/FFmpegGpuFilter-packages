// Port of ApertureWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ApertureWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const AA: f32 = 0.006;

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // Square pixels, normalized so the frame's corners are at distance 1.
    let q = (uv - 0.5) * vec2f(ratio, 1.0) / (0.5 * length(vec2f(ratio, 1.0)));
    let n = clamp(f32(params.blades), 3.0, 12.0);
    let sector = 2.0 * PI / n;
    let turn = radians(params.rotation) * progress;
    // Each blade's straight edge is at distance r from the center: the opening is the polygon they enclose.
    let r = mix(-AA, 1.0 + AA, progress);
    var dist = -1e3;
    var seam = 0.0;
    for (var i = 0; i < 12; i++) {
        if (f32(i) < n) {
            let angle = turn + f32(i) * sector;
            let d = dot(q, vec2f(cos(angle), sin(angle))) - r;
            let next = dot(q, vec2f(cos(angle + sector), sin(angle + sector))) - r;
            dist = max(dist, d);
            let s = 1.0 - smoothstep(0.0, 0.12, -d);
            seam = max(seam, (1.0 - smoothstep(0.0, AA, d)) * s * s * smoothstep(0.0, AA, next));
        }
    }
    let rim = 1.0 - smoothstep(0.0, 0.08, dist);
    let shade = params.shadow * max(rim * rim, seam) * smoothstep(0.0, 0.1, progress);
    var fr = from_color(uv);
    fr = vec4f(fr.rgb * (1.0 - shade), fr.a);
    return mix(fr, to_color(uv), 1.0 - smoothstep(0.0, AA, dist));
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
