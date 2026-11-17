// Guided filter, second pass: out = mean(a) * I + mean(b) over the same box.
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let p = vec2i(id.xy);
    let r = params.radius;
    let lo = max(p - r, vec2i(0));
    let hi = min(p + r, s - 1);
    var sa = vec3f(0.0);
    var sb = vec3f(0.0);
    for (var y = lo.y; y <= hi.y; y++) {
        for (var x = lo.x; x <= hi.x; x++) {
            sa += textureLoad(a, vec2i(x, y), 0).rgb;
            sb += textureLoad(b, vec2i(x, y), 0).rgb;
        }
    }
    let n = f32((hi.x - lo.x + 1) * (hi.y - lo.y + 1));
    let c = textureLoad(src, p, 0);
    gpufx_write(id, vec4f(sa / n * c.rgb + sb / n, c.a));
}
