# Generates gpufx/ffmpeg/vaguedenoiser: its shaders and the passes of its manifest.json.
# usage, from the repository root: py tools/gen_vaguedenoiser.py gpufx/ffmpeg/vaguedenoiser
import sys, os, json
pkg = sys.argv[1]
MAX = 10
os.makedirs(os.path.join(pkg, 'shaders'), exist_ok=True)

COMMON = r'''// Helpers shared by the vaguedenoiser passes (FFmpeg vf_vaguedenoiser.c). The wavelet
// coefficients of the R, G and B channels are f32 values stored as their 32 bits over the
// four 8-bit channels of a texel, one texture per channel.
fn pk(v: f32) -> vec4f {
    let u = bitcast<u32>(v);
    return vec4f(vec4u(u & 255u, (u >> 8u) & 255u, (u >> 16u) & 255u, u >> 24u)) / 255.0;
}
fn up(t: vec4f) -> f32 {
    let b = vec4u(round(t * 255.0));
    return bitcast<f32>(b.x | (b.y << 8u) | (b.z << 16u) | (b.w << 24u));
}
// Number of steps: the param, at most FFmpeg's cap from the picture size.
fn steps() -> i32 {
    let s = vec2i(textureDimensions(src_dims));
    var m = 1;
    for (; m < 15; m++) {
        if ((1 << u32(m)) >= s.x || (1 << u32(m)) >= s.y) { break; }
    }
    return max(min(params.nsteps, m - 2), 0);
}
// Size of the region the transform works on at level k: (n + 1) >> 1, k times.
fn lsize(n: i32, k: i32) -> i32 {
    var v = n;
    for (var i = 0; i < k; i++) { v = (v + 1) >> 1; }
    return v;
}
// Whole-sample symmetric extension ... 2 1 0 | 0 1 2 ... of index m into [0, n).
fn mirror(m: i32, n: i32) -> i32 {
    if (n <= 1) { return 0; }
    let p = 2 * n - 2;
    var v = abs(m) % p;
    if (v >= n) { v = p - v; }
    return v;
}
// FFmpeg's extension of the low half (left whole-sample, right half-sample for even sizes).
fn ext_low(k: i32, n: i32) -> i32 {
    let ls = (n + 1) >> 1;
    var v = k;
    if (v < 0) { v = -v; }
    if (v > ls - 1) { v = select(2 * (ls - 1) - v, 2 * ls - 1 - v, n % 2 == 0); }
    return clamp(v, 0, ls - 1);
}
// FFmpeg's extension of the high half (left half-sample, right whole-sample for even sizes).
fn ext_high(j: i32, n: i32) -> i32 {
    let hs = n >> 1;
    var v = j;
    if (v < 0) { v = -1 - v; }
    if (v > hs - 1) { v = select(2 * hs - 1 - v, 2 * (hs - 1) - v, n % 2 == 0); }
    return clamp(v, 0, max(hs - 1, 0));
}
const AL = array<f32, 5>(0.852698679009403, 0.377402855612654, -0.110624404418423, -0.023849465019380, 0.037828455506995);
const AH = array<f32, 4>(-0.788485616405664, 0.418092273222212, 0.040689417609558, -0.064538882628938);
const SL = array<f32, 4>(0.788485616405664, 0.418092273222212, -0.040689417609558, -0.064538882628938);
const SH = array<f32, 5>(-0.852698679009403, 0.377402855612654, 0.110624404418423, -0.023849465019380, -0.037828455506995);
// Analysis of sample i (of the n along the line, after the low/high split) of a line read by f(m).
'''

def loader(name, tex):
    if tex is None:
        return f'''fn {name}(p: vec2i) -> vec3f {{
    return textureLoad(src, p, 0).rgb * 255.0;
}}
'''
    r, g, b = tex
    return f'''fn {name}(p: vec2i) -> vec3f {{
    return vec3f(up(textureLoad({r}, p, 0)), up(textureLoad({g}, p, 0)), up(textureLoad({b}, p, 0)));
}}
'''

# Body generators: transforms along an axis. `ld` is the loader name.
def fwd_fn(ld):
    return f'''fn fwd(c: vec2i, k: i32, horiz: bool) -> vec3f {{
    let s = vec2i(textureDimensions(src_dims));
    let lh = lsize(s.x, k);
    let lv = lsize(s.y, k);
    if (k >= steps() || c.x >= lh || c.y >= lv) {{ return {ld}(c); }}
    let ax = select(vec2i(0, 1), vec2i(1, 0), horiz);
    let n = select(lv, lh, horiz);
    let i = select(c.y, c.x, horiz);
    let base = c - ax * i;
    let ls = (n + 1) >> 1;
    var acc = vec3f(0.0);
    if (i < ls) {{
        for (var t = -4; t <= 4; t++) {{
            acc += AL[abs(t)] * {ld}(base + ax * mirror(2 * i + t, n));
        }}
    }} else {{
        let j = i - ls;
        for (var t = -3; t <= 3; t++) {{
            acc += AH[abs(t)] * {ld}(base + ax * mirror(2 * j + 1 + t, n));
        }}
    }}
    return acc;
}}
'''

def inv_fn(ld):
    return f'''fn inv(c: vec2i, k: i32, horiz: bool) -> vec3f {{
    let s = vec2i(textureDimensions(src_dims));
    let lh = lsize(s.x, k);
    let lv = lsize(s.y, k);
    if (k >= steps() || c.x >= lh || c.y >= lv) {{ return {ld}(c); }}
    let ax = select(vec2i(0, 1), vec2i(1, 0), horiz);
    let n = select(lv, lh, horiz);
    let y = select(c.y, c.x, horiz);
    let base = c - ax * y;
    let ls = (n + 1) >> 1;
    var acc = vec3f(0.0);
    for (var d = -2; d <= 2; d++) {{
        let kk = (y >> 1) + d;
        let m = abs(y - 2 * kk);
        if (m <= 3) {{ acc += SL[m] * {ld}(base + ax * ext_low(kk, n)); }}
    }}
    for (var d = -2; d <= 2; d++) {{
        let j = ((y - 1) >> 1) + d;
        let m = abs(y - 2 * j - 1);
        if (m <= 4) {{ acc += SH[m] * {ld}(base + ax * (ls + ext_high(j, n))); }}
    }}
    return acc;
}}
'''

def entries(prefix, body_call, ks, write3=True):
    out = ''
    for k in ks:
        out += f'''@compute @workgroup_size(8, 8)
fn {prefix}{k}(@builtin(global_invocation_id) id: vec3u) {{
    if (!gpufx_in_bounds(id)) {{ return; }}
    let v = {body_call.format(k=k)};
    gpufx_write(id, pk(v.r));
    gpufx_write1(id, pk(v.g));
    gpufx_write2(id, pk(v.b));
}}
'''
    return out

def common(dims):
    return COMMON.replace('src_dims', dims)

A = ('ar', 'ag', 'ab'); B = ('br', 'bg', 'bb')
files = {}
# first.wgsl: horizontal analysis of level 0 from the source picture.
files['first.wgsl'] = common('src') + loader('ld', None) + fwd_fn('ld') + entries('fh', 'fwd(vec2i(id.xy), {k}, true)', [0])
# a.wgsl: passes reading A.
files['a.wgsl'] = common('ar') + loader('ld', A) + fwd_fn('ld') + inv_fn('ld') + \
    entries('fh', 'fwd(vec2i(id.xy), {k}, true)', range(1, MAX)) + \
    entries('ih', 'inv(vec2i(id.xy), {k}, true)', range(1, MAX)) + r'''
// Bayes: sum of squares of row y of sub-band x (x = 4 level + band; band 0 LL of the last
// level, 1 high-low, 2 low-high, 3 high-high).
fn band_rect(id: i32) -> vec4i {
    let s = vec2i(textureDimensions(ar));
    let n = id / 4;
    let band = id % 4;
    if (n >= steps() || (band == 0 && n != steps() - 1)) { return vec4i(0); }
    let lh = lsize(s.x, n);
    let lv = lsize(s.y, n);
    let hl = (lh + 1) >> 1;
    let vl = (lv + 1) >> 1;
    let x0 = select(0, hl, (band & 1) != 0);
    let y0 = select(0, vl, (band & 2) != 0);
    let w = select(hl, lh >> 1, (band & 1) != 0);
    let h = select(vl, lv >> 1, (band & 2) != 0);
    return vec4i(x0, y0, w, h);
}
@compute @workgroup_size(8, 8)
fn rows(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    var acc = vec3f(0.0);
    let r = band_rect(i32(id.x));
    if (params.threshold_type == 1 && i32(id.y) < r.w && id.x < 4u * 10u) {
        let y = r.y + i32(id.y);
        for (var x = r.x; x < r.x + r.z; x++) {
            let v = ld(vec2i(x, y));
            acc += v * v;
        }
    }
    gpufx_write(id, pk(acc.r));
    gpufx_write1(id, pk(acc.g));
    gpufx_write2(id, pk(acc.b));
}
'''
files['a.wgsl'] = files['a.wgsl'].replace('i32(id.y) < r.w', 'i32(id.y) < r.w')
# fix: rows of the band are r.w (height is r.w component 3)
files['a.wgsl'] = files['a.wgsl'].replace('i32(id.y) < r.w &&', 'i32(id.y) < r.w &&')
# b.wgsl: passes reading B.
files['b.wgsl'] = common('br') + loader('ld', B) + fwd_fn('ld') + inv_fn('ld') + \
    entries('fv', 'fwd(vec2i(id.xy), {k}, false)', range(0, MAX)) + \
    entries('iv', 'inv(vec2i(id.xy), {k}, false)', range(0, MAX))
# last.wgsl: horizontal synthesis of level 0, written as the picture.
files['last.wgsl'] = common('ar') + loader('ld', A) + inv_fn('ld') + r'''
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let c = vec2i(id.xy);
    let px = textureLoad(src, c, 0);
    let v = inv(c, 0, true);
    // FFmpeg's planes bits on gbrp: 1 G, 2 B, 4 R.
    let on = vec3<bool>((params.planes & 4) != 0, (params.planes & 1) != 0, (params.planes & 2) != 0);
    let o = select(px.rgb, clamp(trunc(v + 0.5), vec3f(0.0), vec3f(255.0)) / 255.0, on);
    gpufx_write(id, vec4f(o, px.a));
}
'''
files['tot.wgsl'] = COMMON.replace('src_dims', 'sr') + r'''
// Bayes: total of the row sums of each sub-band, in the texel (sub-band, 0).
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    var acc = vec3f(0.0);
    if (id.y == 0u && params.threshold_type == 1) {
        let h = i32(textureDimensions(sr).y);
        for (var y = 0; y < h; y++) {
            let p = vec2i(i32(id.x), y);
            acc += vec3f(up(textureLoad(sr, p, 0)), up(textureLoad(sg, p, 0)), up(textureLoad(sb, p, 0)));
        }
    }
    gpufx_write(id, pk(acc.r));
    gpufx_write1(id, pk(acc.g));
    gpufx_write2(id, pk(acc.b));
}
'''
files['thr.wgsl'] = common('ar') + loader('ld', A) + r'''
fn shrink(v: f32, thr: f32) -> f32 {
    let p01 = params.percent * 0.01;
    let a = abs(v);
    if (a <= thr) { return v * (1.0 - p01); }
    if (params.method == 0) { return v; }
    if (params.method == 1) { return sign(v) * (a - thr * p01); }
    let tr2 = thr * thr * p01;
    let tp2 = a * a;
    return v * ((tp2 - tr2) / tp2);
}
fn bayes(sum: f32, area: i32) -> f32 {
    let t = params.threshold;
    let mean = sum / f32(area);
    let q = mean - t;
    var d = 1.1920929e-7;
    if (q > 0.0) { d = max(sqrt(q), d); }
    return t * t / d;
}
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) id: vec3u) {
    if (!gpufx_in_bounds(id)) { return; }
    let c = vec2i(id.xy);
    let v = ld(c);
    var thr = vec3f(params.threshold);
    if (params.threshold_type == 1) {
        let s = vec2i(textureDimensions(ar));
        let ns = steps();
        var n = 0;
        for (var k = 1; k < ns; k++) {
            if (c.x < lsize(s.x, k) && c.y < lsize(s.y, k)) { n = k; }
        }
        let lh = lsize(s.x, n);
        let lv = lsize(s.y, n);
        let hl = (lh + 1) >> 1;
        let vl = (lv + 1) >> 1;
        let band = select(0, 1, c.x >= hl) + select(0, 2, c.y >= vl);
        let w = select(hl, lh >> 1, (band & 1) != 0);
        let h = select(vl, lv >> 1, (band & 2) != 0);
        let p = vec2i(4 * n + band, 0);
        let sum = vec3f(up(textureLoad(tr, p, 0)), up(textureLoad(tg, p, 0)), up(textureLoad(tb, p, 0)));
        thr = vec3f(bayes(sum.r, w * h), bayes(sum.g, w * h), bayes(sum.b, w * h));
    }
    gpufx_write(id, pk(shrink(v.r, thr.r)));
    gpufx_write1(id, pk(shrink(v.g, thr.g)));
    gpufx_write2(id, pk(shrink(v.b, thr.b)));
}
'''
DIMS={'first.wgsl':'src','b.wgsl':'br','tot.wgsl':'sr'}
for n, t in files.items():
    t = t.replace('src_dims', DIMS.get(n, 'ar'))
    open(os.path.join(pkg, 'shaders', n), 'w', encoding='utf-8', newline='\n').write(t)

P = []
def ps(shader, entry, inputs, outputs):
    d = {"shader": "shaders/" + shader}
    if entry != 'main': d["entry"] = entry
    d["inputs"] = inputs; d["outputs"] = outputs
    P.append(d)
LA = list(A); LB = list(B)
ps('first.wgsl', 'fh0', ['src'], LB)
ps('b.wgsl', 'fv0', LB, LA)
for k in range(1, MAX):
    ps('a.wgsl', f'fh{k}', LA, LB)
    ps('b.wgsl', f'fv{k}', LB, LA)
ps('a.wgsl', 'rows', LA, ['sr', 'sg', 'sb'])
ps('tot.wgsl', 'main', ['sr', 'sg', 'sb'], ['tr', 'tg', 'tb'])
ps('thr.wgsl', 'main', LA + ['tr', 'tg', 'tb'], LB)
for k in range(MAX - 1, 0, -1):
    ps('b.wgsl', f'iv{k}', LB, LA)
    ps('a.wgsl', f'ih{k}', LA, LB)
ps('b.wgsl', 'iv0', LB, LA)
ps('last.wgsl', 'main', LA + ['src'], ['out'])

m = {
  "api": 1,
  "id": "io.github.tqk2811.vaguedenoiser",
  "name": "Vague Denoiser",
  "used_for": ["gpufx"],
  "version": "1.0.0",
  "description": "Wavelet denoiser on one frame: shrinks the small wavelet coefficients of each channel.",
  "inputs": [{"name": "src", "description": "Picture to denoise"}],
  "params": [
    {"name": "threshold", "type": "float", "default": 2.0, "min": 0.0, "max": 255.0, "description": "Filtering strength: coefficients up to this size are shrunk"},
    {"name": "method", "type": "enum", "values": ["hard", "soft", "garrote"], "default": "garrote", "description": "Shrinking of the coefficients above the threshold: kept, moved toward 0 by the threshold, or non-negative garrote"},
    {"name": "nsteps", "type": "int", "default": 6, "min": 1, "max": MAX, "description": "Number of wavelet decomposition steps (lowered for small pictures as FFmpeg does)"},
    {"name": "percent", "type": "float", "default": 85.0, "min": 0.0, "max": 100.0, "description": "Percent of full denoising of the coefficients below the threshold"},
    {"name": "planes", "type": "int", "default": 15, "min": 0, "max": 15, "description": "Channels to filter, FFmpeg's bits on gbrp: 1 green, 2 blue, 4 red"},
    {"name": "threshold_type", "type": "enum", "values": ["universal", "bayes"], "default": "universal", "description": "Threshold: the same for the whole picture (VisuShrink), or one per sub-band from its energy (BayesShrink)"}
  ],
  "groups": [{"passes": P}]
}
s = json.dumps(m, indent=2)
open(os.path.join(pkg, 'manifest.json'), 'w', encoding='utf-8', newline='\n').write(s + '\n')
