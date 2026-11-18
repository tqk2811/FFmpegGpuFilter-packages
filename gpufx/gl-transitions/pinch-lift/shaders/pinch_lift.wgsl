// Port of PinchLift.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/PinchLift.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;

fn gl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

// Width of the hanging fan (1 = flat picture, small = cloth hanging straight down) at distance r from the pinch.
fn fan_width(t: f32, r: f32) -> f32 {
    // The far cloth swings a longer arc and arrives later, so the hem lags behind in a curve.
    let a = clamp((t - 0.03 - 0.1 * r) / 0.45, 0.0, 1.0);
    let s = a * a * (3.0 - 2.0 * a) + 0.15 * sin(PI * a) * a * a;
    let m = smoothstep(0.5, 1.0, t);
    return mix(1.0, 0.3, s) + 0.12 * m * min(r, 1.0);
}

fn pleat_phase(th: f32) -> f32 {
    return floor(params.pleats + 0.5) * th + 0.8 * sin(3.0 * th + 1.0) + 0.5 * sin(5.0 * th + 2.0);
}

// Angle of d away from straight down below the pinch, in -PI..PI.
fn hang_angle(d: vec2f, sway: f32) -> f32 {
    var th = 0.0;
    if (abs(d.x) + abs(d.y) > 0.0) { th = atan2(d.x, -d.y); }
    return gl_mod(th - sway + PI, 2.0 * PI) - PI;
}

// xy: point of the first clip (aspect units), z: gathering (0 flat .. 1 hanging), w: distance to the fan edge.
fn cloth(d: vec2f, t: f32, pin: vec2f, sway: f32) -> vec4f {
    let r = length(d);
    let th = hang_angle(d, sway);
    let w = fan_width(t, r);
    let th0 = th / w;
    let a = clamp((1.0 - w) / 0.7, 0.0, 1.0);
    // Pleats fold the angle back and forth, so the extra width hides in the folds
    // (not at the fan's edges, which stay on the picture's top edge above the pinch).
    let k = pleat_phase(th0);
    let th1 = th0 + 0.9 * a * sin(k) * smoothstep(0.0, 0.3, PI - abs(th0)) / floor(params.pleats + 0.5);
    let r0 = r * (1.0 + 0.12 * a * (0.5 - 0.5 * cos(k)));
    let o = pin + r0 * vec2f(sin(th1), -cos(th1));
    return vec4f(o, a, (PI * w - abs(th)) * r);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress;
    let asp = vec2f(ratio, 1.0);
    let pin = vec2f(params.center.x, 1.0 - params.center.y) * asp;
    let m = clamp((t - 0.52) / 0.48, 0.0, 1.0);
    let cc = pin - vec2f(0.0, m * m * (pin.y + 0.25));
    let a = clamp((t - 0.1) / 0.45, 0.0, 1.0);
    let sway = params.swing * (0.22 * sin(2.6 * PI * a) * (1.0 - a) * a * 3.0 - 0.08 * m);

    let d = uv * asp - cc;
    let r = length(d);
    let c = cloth(d, t, pin, sway);
    let src = c.xy / asp;
    let bd = min(src, 1.0 - src) * asp;
    // Antialiased edge (no edge on the frame's border at the start).
    let e = 0.002 * (1.0 + 2.0 * c.z) * min(1.0, 30.0 * t) + 1e-5;
    var cov = clamp(min(bd.x, bd.y) / e + 0.5, 0.0, 1.0);
    // The opening above the pinch, filtered over the pixel: x is the distance to the seam straight
    // above the pinch and h the opening's half width, so nothing opens while the fan is flat.
    let w = fan_width(t, r);
    let h = PI * (1.0 - w) * r;
    let x = c.w + h;
    cov *= 1.0 - clamp((min(x + 0.5 * e, h) - max(x - 0.5 * e, -h)) / e, 0.0, 1.0);

    var img = vec4f(0.0);
    if (cov > 0.0) {
        img = from_color(clamp(src, vec2f(0.0), vec2f(1.0)));
        let th = hang_angle(d, sway) / w;
        let nn = floor(params.pleats + 0.5);
        let k = pleat_phase(th);
        let amp = 0.6 + 0.4 * sin(2.0 * th + 2.5) * sin(3.0 * th + 0.7);
        let aa = sqrt(c.z) * params.depth * amp * smoothstep(0.0, 0.25, r);
        let aw = 0.003 * nn / max(r * w, 1e-3) + 0.05;
        let face = clamp(sin(k) / aw, -1.0, 1.0);
        let valley = pow(0.5 - 0.5 * cos(k), 3.0);
        var shade = 1.0 + aa * (0.45 * face * (0.4 + 0.6 * abs(sin(k))) - 0.55 * valley);
        shade += 0.2 * params.depth * c.z * (1.0 - smoothstep(0.0, 0.06, r));
        shade -= 0.15 * params.depth * c.z * smoothstep(0.2, 1.0, r);
        shade -= 0.35 * params.depth * sqrt(c.z) * exp(-c.w / 0.025);
        img = vec4f(img.rgb * max(shade, 0.0), img.a);
        if (cov >= 1.0) { return img; }
    }

    var bg = to_color(uv);
    let lift = sin(PI * t);
    if (lift > 0.0) {
        let cs = cloth(d - vec2f(0.03, -0.035), t, pin, sway);
        let ss = cs.xy / asp;
        let sb = min(ss, 1.0 - ss) * asp;
        let sh = smoothstep(-0.05, 0.04, min(min(sb.x, sb.y), cs.w));
        // And a darker contact shade in the opening above the pinch, so it reads as a fold, not a crack.
        let edge = select(PI, -PI, hang_angle(d, sway) < 0.0) * w * 0.999 + sway;
        let es = cloth(r * vec2f(sin(edge), -cos(edge)), t, pin, sway).xy / asp;
        let eb = min(es, 1.0 - es) * asp;
        var gap = (1.0 - m * m) * smoothstep(-0.01, 0.0, -c.w) * (1.0 - smoothstep(0.0, 0.05, -c.w));
        gap *= smoothstep(-0.01, 0.01, min(eb.x, eb.y));
        bg = vec4f(bg.rgb * (1.0 - params.shadow * 0.55 * sh * lift) * (1.0 - params.shadow * 0.55 * gap), bg.a);
    }
    return mix(bg, img, cov);
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
