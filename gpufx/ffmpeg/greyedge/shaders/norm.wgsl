// Grey edge, first pass: the Gaussian derivative magnitude of each R, G, B channel at the
// pixel, on 8-bit codes, set to 0 where the channel is saturated (255), written as the 32 bits
// of an f32 over the RGBA8 texels of nr, ng and nb (FFmpeg vf_colorconstancy.c).
const MAX_SIZE: i32 = 61;

fn pack(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}

var<private> g0: array<f32, 61>;
var<private> g1: array<f32, 61>;
var<private> g2: array<f32, 61>;

// Tap offset of kernel entry i. FFmpeg's GINDX uses size >> 2, not size >> 1, so the kernels
// are off centre; kept for parity.
fn offs(size: i32, i: i32) -> i32 {
    return i - (size >> 2u);
}

fn set_gauss(size: i32, sigma: f32, order: i32) {
    if (sigma == 0.0) {
        g0[0] = 1.0;
    } else {
        var sum = 0.0;
        for (var i = 0; i < size; i++) {
            let x = f32(offs(size, i));
            g0[i] = exp(-x * x / (2.0 * sigma * sigma)) / (sqrt(2.0 * 3.14159265358979) * sigma);
            sum += g0[i];
        }
        for (var i = 0; i < size; i++) { g0[i] /= sum; }
    }
    if (order > 0) {
        var sum = 0.0;
        for (var i = 0; i < size; i++) {
            let x = f32(offs(size, i));
            g1[i] = -(x / (sigma * sigma)) * g0[i];
            sum += g1[i] * x;
        }
        for (var i = 0; i < size; i++) { g1[i] /= sum; }
    }
    if (order > 1) {
        var sum1 = 0.0;
        for (var i = 0; i < size; i++) {
            let x = f32(offs(size, i));
            g2[i] = (x * x / pow(sigma, 4.0) - 1.0 / (sigma * sigma)) * g0[i];
            sum1 += g2[i];
        }
        var sum2 = 0.0;
        for (var i = 0; i < size; i++) {
            let x = f32(offs(size, i));
            g2[i] -= sum1 / f32(size);
            sum2 += 0.5 * x * x * g2[i];
        }
        for (var i = 0; i < size; i++) { g2[i] /= sum2; }
    }
}

fn tap(order: i32, i: i32) -> f32 {
    if (order == 0) { return g0[i]; }
    if (order == 1) { return g1[i]; }
    return g2[i];
}

// Separable filter: kernel `ox` along the row, then `oy` along the column, edges clamped.
fn conv(p: vec2i, size: i32, ox: i32, oy: i32) -> vec3f {
    let s = vec2i(textureDimensions(src));
    var acc = vec3f(0.0);
    for (var h = 0; h < size; h++) {
        let y = clamp(p.y + offs(size, h), 0, s.y - 1);
        var row = vec3f(0.0);
        for (var g = 0; g < size; g++) {
            let x = clamp(p.x + offs(size, g), 0, s.x - 1);
            row += round(textureLoad(src, vec2i(x, y), 0).rgb * 255.0) * tap(ox, g);
        }
        acc += row * tap(oy, h);
    }
    return acc;
}

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let sigma = params.sigma;
    let size = min(2 * i32(floor(3.0 * sigma + 0.5)) + 1, MAX_SIZE);
    let order = params.difford;
    set_gauss(size, sigma, order);
    let p = vec2i(id.xy);
    var n: vec3f;
    if (order == 0) {
        n = conv(p, size, 0, 0);
    } else if (order == 1) {
        let dx = conv(p, size, 1, 0);
        let dy = conv(p, size, 0, 1);
        n = sqrt(dx * dx + dy * dy);
    } else {
        let dx = conv(p, size, 2, 0);
        let dy = conv(p, size, 0, 2);
        let dxy = conv(p, size, 1, 1);
        n = sqrt(dx * dx + 4.0 * dxy * dxy + dy * dy);
    }
    let code = round(textureLoad(src, p, 0).rgb * 255.0);
    n = select(vec3f(0.0), abs(n), code < vec3f(255.0));
    gpufx_write(id, pack(n.r));
    gpufx_write1(id, pack(n.g));
    gpufx_write2(id, pack(n.b));
}
