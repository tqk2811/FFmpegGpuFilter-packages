// Port of Crumple.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Crumple.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;

fn gl_mod2(x: vec2f, y: f32) -> vec2f { return x - y * floor(x / y); }
fn gl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn hash2(p0: vec2f) -> vec2f {
    let p = vec2f(dot(p0, vec2f(127.1, 311.7)), dot(p0, vec2f(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

fn rot(a: f32) -> mat2x2f {
    let s = sin(a);
    let c = cos(a);
    return mat2x2f(c, -s, s, c);
}

fn frame(a: vec2f, ratio: f32) -> f32 {
    return min(0.5 * ratio / max(abs(a.x), 1e-4), 0.5 / max(abs(a.y), 1e-4));
}

// Distance from the center to the edge of the paper in the direction a (unit vector): the frame
// shrinking and buckling while it crumples (c), turning into a lumpy ball (k).
fn outline(a: vec2f, c: f32, k: f32, radius: f32, ratio: f32) -> f32 {
    let rect = frame(a, ratio);
    let th = atan2(a.y, a.x);
    let buckle = 0.03 + 0.05 * abs(sin(4.0 * th + 0.7)) + 0.03 * abs(sin(9.0 * th + 2.0)) + 0.015 * abs(sin(23.0 * th + 1.3));
    let i = floor((th / (2.0 * PI) + 0.5) * 9.0);
    let a0 = i * 2.0 * PI / 9.0 - PI;
    let a1 = a0 + 2.0 * PI / 9.0;
    let v0 = vec2f(cos(a0), sin(a0)) * (0.78 + 0.27 * hash2(vec2f(gl_mod(i, 9.0), 3.0)).x);
    let v1 = vec2f(cos(a1), sin(a1)) * (0.78 + 0.27 * hash2(vec2f(gl_mod(i + 1.0, 9.0), 3.0)).x);
    let e = v1 - v0;
    let ball = radius * (v0.x * e.y - v0.y * e.x) / (a.x * e.y - a.y * e.x);
    return mix(rect * mix(1.0, 0.75, c) * (1.0 - c * buckle), ball, k);
}

struct Folds {
    grad: vec2f,
    shift: vec2f,
    valley: f32,
    ridge: f32,
}

// n straight creases of random position, orientation and length, in a space where the paper
// spans about [-span, span]; each one tilts the paper on its two sides (a sharp ridge or valley
// between flat facets) and swallows a strip of the picture. They come one after another as c
// grows; px is the half width of a crease line, in the units of x.
fn fold(x: vec2f, seed: f32, n: i32, span: vec2f, len: f32, c: f32, px: f32, weight: f32) -> Folds {
    var r = Folds(vec2f(0.0), vec2f(0.0), 0.0, 0.0);
    let tilt = 2.0 / sqrt(f32(n));
    for (var i = 0; i < 32; i++) {
        if (i >= n) { break; }
        let fi = f32(i);
        let h = hash2(vec2f(fi, seed));
        let g = hash2(vec2f(fi, seed + 11.8));
        let o = (h - 0.5) * 2.0 * span;
        let nrm = vec2f(cos(2.0 * PI * g.x), sin(2.0 * PI * g.x));
        let d = dot(x - o, nrm);
        let along = dot(x - o, vec2f(-nrm.y, nrm.x));
        let l = len * (0.5 + g.y);
        let start = 0.4 * fi / f32(n);
        let act = weight * smoothstep(start, start + 0.3, c) * (1.0 - smoothstep(0.5 * l, l, abs(along)));
        let amp = select(-1.0, 1.0, h.x > 0.5) * (0.5 + 0.5 * h.y);
        let side = d / (abs(d) + px);
        r.grad += act * amp * side * nrm * tilt;
        r.shift += act * 0.03 * side * nrm;
        let line = 1.0 - smoothstep(0.0, 2.0 * px, abs(d));
        if (amp < 0.0) { r.valley += act * line; } else { r.ridge += act * line * amp; }
    }
    return r;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let b = to_color(uv);

    // Crumpling (c), balling up (k), then tossing (t).
    let c = smoothstep(0.0, 0.6, progress);
    let k = smoothstep(0.1, 0.62, progress);
    var t = smoothstep(0.58, 1.0, progress);
    t *= t;

    var dir = vec2f(1.0, 0.0);
    if (length(params.direction) > 0.0) { dir = normalize(params.direction); }
    let radius = max(params.size, 0.01) * mix(1.0, 0.6, t);
    // Far enough along the direction for the ball and its shadow (offset and blurred by up to
    // about 0.09 each) to leave the frame.
    let reach = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + 1.2 * radius + 0.3;
    let bend = select(1.0, -1.0, dir.x < 0.0);
    let center = dir * reach * t + vec2f(-dir.y, dir.x) * 0.15 * bend * sin(PI * t);
    let angle = 0.6 * c - 5.0 * bend * t;
    let lift = 0.012 * c + 0.06 * t;

    let p = (uv - 0.5) * vec2f(ratio, 1.0);

    let sp = rot(angle) * (p - center - vec2f(0.6, -1.0) * lift);
    let sl = length(sp);
    let sd = sl - outline(select(vec2f(1.0, 0.0), sp / sl, sl > 1e-5), c, k, radius, ratio);
    let blur = 0.005 + 1.2 * lift;
    let col = vec4f(mix(b.rgb, params.shadow.rgb, params.shadow.a * c * (1.0 - smoothstep(-blur, blur, sd))), b.a);

    let q = rot(angle) * (p - center);
    let l = length(q);
    let dq = select(vec2f(1.0, 0.0), q / l, l > 1e-5);
    let edge = outline(dq, c, k, radius, ratio);
    // The edge (about a pixel at 300 px high) is antialiased only once the sheet has left the
    // borders of the frame.
    let aa = 0.003 * smoothstep(0.0, 0.1, progress) + 1e-5;
    let inside = 1.0 - smoothstep(-aa, aa, l - edge);
    if (inside <= 0.0) { return col; }

    // Back onto the flat sheet: the outline is mapped onto the frame, the middle of the ball holds
    // more of it, as if the edges were tucked under.
    let r = l / edge;
    let rect = frame(dq, ratio);
    let s = dq * rect * mix(r, r * (0.6 + 0.4 * r), k);

    let count = max(params.creases, 1);
    let f1 = fold(s, 7.3, count, 0.45 * vec2f(ratio, 1.0), 0.6, c, 0.003 * rect / edge, 1.0 - 0.8 * k);
    let f2 = fold(q / radius, 2.9, count, vec2f(0.7), 8.0, k, 0.003 / radius, k);
    let grad = f1.grad + f2.grad * 0.8;
    let piece = s + f1.shift + f2.shift * 3.0;

    // Facets over the ball's volume, lit from the top left (the light does not turn with the ball).
    let rr = clamp(l / (radius * 1.1), 0.0, 1.0);
    let sphere = vec3f(q / (radius * 1.1) * k * 0.8, sqrt(1.0 - 0.64 * rr * rr * k));
    var n = normalize(sphere + vec3f(grad, 0.0));
    n = vec3f(rot(-angle) * n.xy, n.z);
    let light = normalize(vec3f(-0.5, 0.6, 0.8));
    let diffuse = max(dot(n, light), 0.0);
    let hv = normalize(light + vec3f(0.0, 0.0, 1.0));
    // Only what facets add over the flat sheet.
    let spec = max(pow(max(dot(n, hv), 0.0), 20.0) - pow(hv.z, 20.0), 0.0);
    let level = light.z;
    let relief = min(2.0 * c, 1.0);
    var shade = 1.0 + relief * ((0.12 + diffuse) / (0.12 + level) - 1.0) + 0.7 * spec * relief;
    shade -= 0.2 * relief * min(f1.valley, 1.0);
    shade *= 1.0 - 0.3 * k * smoothstep(0.6, 1.0, r);

    // The edges of the sheet that the folds pull in are mirrored, as if folded back.
    let f = piece / vec2f(ratio, 1.0) + 0.5;
    let img = from_color(1.0 - abs(1.0 - gl_mod2(f, 2.0)));
    let ink = mix(img.rgb, params.paper.rgb, 0.6 * min(f1.ridge, 1.0) * params.paper.a * c);
    let ball = vec4f(ink * shade, img.a);

    // Mixed premultiplied, so transparent clips do not bleed their color.
    let m = inside * ball.a;
    let o = vec4f(mix(col.rgb * col.a, ball.rgb, m), mix(col.a, 1.0, m));
    if (o.a > 0.0) { return vec4f(o.rgb / o.a, o.a); }
    return vec4f(0.0);
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
