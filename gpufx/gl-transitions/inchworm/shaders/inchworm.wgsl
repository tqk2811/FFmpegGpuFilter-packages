// Port of Inchworm.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Inchworm.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.14159265;
const STRIDE: f32 = 0.5;
const AA: f32 = 0.002;
const LIGHT: vec3f = vec3f(-0.5847, 0.3118, 0.7484);

fn iw_ease(x0: f32) -> f32 {
    let x = clamp(x0, 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

fn iw_hump(x: f32, a: f32, span: f32, h: f32) -> f32 {
    let u = clamp((x - a) / span, 0.0, 1.0);
    let s = sin(PI * pow(u, 0.8));
    return h * s * s;
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let t = progress * 3.0;
    // Overlapping beats keep the crawl flowing: gather, reach, gather.
    let g = iw_ease(t / 1.2) + iw_ease((t - 1.8) / 1.2);
    let reach = iw_ease((t - 0.8) / 1.4);
    // Two gathers carry the back edge just past the right side of the frame.
    let a = STRIDE * g * ratio + 0.003 * g;
    let span = (1.0 + STRIDE * reach) * ratio - a;
    // Follows the sheet's length, eased off on wide frames so the arch never nears the eye.
    var h = params.arch * 0.55 * (ratio - span) * sqrt((ratio + span) / ratio);
    h = min(h / (1.0 + 0.5 * h), 1.2);
    // Seen from slightly below, so the raised arch lifts its bottom edge off the floor.
    let eye = vec3f(0.5 * ratio, -1.0, 1.8);
    let ray = vec3f(uv.x * ratio, uv.y, 0.0) - eye;
    let s0 = 1.0 - (h + 0.001) / eye.z;
    var sl = s0;
    var fl = eye.z * (1.0 - s0) - iw_hump(eye.x + s0 * ray.x, a, span, h);
    var sr = 1.0;
    var side = 0;
    for (var i = 1; i <= 40; i++) {
        let s = mix(s0, 1.0, f32(i) / 40.0);
        let f = eye.z * (1.0 - s) - iw_hump(eye.x + s * ray.x, a, span, h);
        let y = eye.y + s * ray.y;
        if ((fl > 0.0) != (f > 0.0) && y > -2.0 * AA && y < 1.0 + 2.0 * AA) {
            sr = s;
            side = select(2, 1, fl > 0.0);
            break;
        }
        sl = s;
        fl = f;
    }
    var fr = eye.z * (1.0 - sr) - iw_hump(eye.x + sr * ray.x, a, span, h);
    for (var i = 0; i < 5; i++) {
        let sm = 0.5 * (sl + sr);
        let fm = eye.z * (1.0 - sm) - iw_hump(eye.x + sm * ray.x, a, span, h);
        if ((fm > 0.0) == (fl > 0.0)) {
            sl = sm;
            fl = fm;
        } else {
            sr = sm;
            fr = fm;
        }
    }
    // A final secant step lands exactly on the floor where the sheet lies flat.
    var sh = sr;
    if (abs(fl - fr) > 1e-6) { sh = sl + (sr - sl) * fl / (fl - fr); }
    let hit = eye + sh * ray;
    var len = 0.0;
    var tot = 0.0;
    var prev = 0.0;
    for (var i = 1; i <= 24; i++) {
        let x = a + span * f32(i) / 24.0;
        let z = iw_hump(x, a, span, h);
        let seg = sqrt(span * span / 576.0 + (z - prev) * (z - prev));
        tot += seg;
        len += seg * clamp((hit.x - x) * 24.0 / span + 1.0, 0.0, 1.0);
        prev = z;
    }
    let e = 0.002 * ratio;
    let dz = (iw_hump(hit.x + e, a, span, h) - iw_hump(hit.x - e, a, span, h)) / (2.0 * e);
    let n = normalize(vec3f(-dz, 0.0, 1.0));
    var light = (0.45 + 0.55 * max(dot(n, LIGHT), 0.0)) / (0.45 + 0.55 * LIGHT.z);
    // The underside of the arch only gets light bounced off the floor.
    if (side == 2) { light = 0.35; }
    var sheet = from_color(vec2f(len / max(tot, 1e-6), clamp(hit.y, 0.0, 1.0)));
    sheet = vec4f(sheet.rgb * light, sheet.a);
    var cov = 0.0;
    if (side > 0) {
        cov = smoothstep(-2.0 * AA, 0.0, hit.y) * smoothstep(-2.0 * AA, 0.0, 1.0 - hit.y) * smoothstep(a - 2.0 * AA, a, hit.x);
    }
    var occ = 0.0;
    for (var i = 1; i <= 8; i++) {
        let z = h * f32(i) / 8.0;
        let x = uv.x * ratio + z * LIGHT.x / LIGHT.z;
        let y = uv.y + z * LIGHT.y / LIGHT.z;
        let inside = smoothstep(-0.02, 0.0, y) * smoothstep(-0.02, 0.0, 1.0 - y);
        occ = max(occ, inside * smoothstep(0.0, 0.04, iw_hump(x, a, span, h) - z));
    }
    var floor_color = to_color(uv);
    let ao = smoothstep(0.0, 0.3, iw_hump(uv.x * ratio, a, span, h));
    floor_color = vec4f(floor_color.rgb * (1.0 - 0.5 * occ) * (1.0 - 0.3 * ao), floor_color.a);
    return mix(floor_color, sheet, cov);
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
