// Guided filter, first pass: per pixel, the box mean and variance of the picture give the
// coefficients of the local linear model out = a * I + b (FFmpeg vf_guided.c, guidance off).
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let s = vec2i(textureDimensions(src));
    let p = vec2i(id.xy);
    let r = params.radius;
    let lo = max(p - r, vec2i(0));
    let hi = min(p + r, s - 1);
    var sum = vec3f(0.0);
    var sq = vec3f(0.0);
    for (var y = lo.y; y <= hi.y; y++) {
        for (var x = lo.x; x <= hi.x; x++) {
            let c = textureLoad(src, vec2i(x, y), 0).rgb;
            sum += c;
            sq += c * c;
        }
    }
    let n = f32((hi.x - lo.x + 1) * (hi.y - lo.y + 1));
    let mean = sum / n;
    let variance = max(sq / n - mean * mean, vec3f(0.0));
    let a = variance / (variance + params.eps);
    let b = mean - a * mean;
    gpufx_write(id, vec4f(a, 1.0));
    gpufx_write1(id, vec4f(b, 1.0));
}
