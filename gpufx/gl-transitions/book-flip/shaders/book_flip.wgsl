// Port of BookFlip.glsl from gl-transitions (author: hong, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BookFlip.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0015;
const CURL_PART: f32 = 0.45;
// Direction of the light, in (x, height toward the viewer).
const LIGHT: vec2f = vec2f(-0.447214, 0.894427);

fn cross2(a: vec2f, b: vec2f) -> f32 { return a.x * b.y - a.y * b.x; }

// The page angle, 0 lying on the right to PI lying on the left: eased, but never at rest.
fn page_angle(progress: f32) -> f32 {
    let p = clamp(progress, 0.0, 1.0);
    return PI * p * (0.35 + p * (1.95 - 1.3 * p));
}

// The page seen in a cross-section across the spine, in (x, height toward the viewer): a
// straight part at angle a, then, when k is not 0, an arc of curvature k centered on c up to
// its free edge. Returns the nearest hit of the ray from eye along dir as (ray length,
// distance along the page, angle there), with a negative ray length when it is missed.
fn hit_page(eye: vec2f, dir: vec2f, a: f32, k: f32, straight: f32, c: vec2f, w: f32) -> vec3f {
    var best = vec3f(-1.0, 0.0, 0.0);
    let d = vec2f(cos(a), sin(a));
    let den = cross2(d, dir);
    if (abs(den) > 1e-7) {
        let u = cross2(eye, dir) / den;
        let t = cross2(eye, d) / den;
        if (t > 0.0 && u >= 0.0 && u <= straight) { best = vec3f(t, u, a); }
    }
    if (k != 0.0) {
        let r = 1.0 / k;
        let oc = eye - c;
        let qa = dot(dir, dir);
        let qb = dot(oc, dir);
        let disc = qb * qb - qa * (dot(oc, oc) - r * r);
        if (disc >= 0.0) {
            let sq = sqrt(disc);
            for (var i = 0; i < 2; i++) {
                let t = (-qb + select(sq, -sq, i == 0)) / qa;
                if (t > 0.0 && (best.x < 0.0 || t < best.x)) {
                    let v = (oc + t * dir) * k;
                    var db = atan2(v.x, -v.y) - a;
                    db -= 2.0 * PI * floor((db + PI) / (2.0 * PI));
                    let s = db / k;
                    if (s >= 0.0 && s <= w - straight) { best = vec3f(t, straight + s, a + db); }
                }
            }
        }
    }
    return best;
}

fn curl_point(c: vec2f, k: f32, b: f32) -> vec2f { return c + vec2f(sin(b), -cos(b)) / k; }

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let a = page_angle(progress);
    let lift = sin(a);
    let w = 0.5 * ratio;
    let x = uv.x * ratio - w;
    let dist = w * (1.0 + 1.5 / max(params.perspective, 0.01));
    let eye = vec2f(0.0, dist);
    let dir = vec2f(x, -dist);
    let d = vec2f(cos(a), sin(a));
    var k = -clamp(params.curl, 0.0, 1.0) * lift / (CURL_PART * w);
    if (abs(k) * CURL_PART * w <= 1e-4) { k = 0.0; }
    let curled = k != 0.0;
    let straight = select(w, (1.0 - CURL_PART) * w, curled);
    let c = straight * d + vec2f(-d.y, d.x) / select(1.0, k, curled);
    let bend = straight * d;
    var middle = bend;
    var edge = bend;
    if (curled) {
        middle = curl_point(c, k, a + 0.5 * k * (w - straight));
        edge = curl_point(c, k, a + k * (w - straight));
    }
    // Anti-aliased edges only once the page has left the frame plane.
    let aa = EDGE * min(20.0 * lift, 1.0);
    var img = vec4f(0.0);
    var m = 0.0;
    let hit = hit_page(eye, dir, a, k, straight, c, w);
    if (hit.x > 0.0) {
        let t = hit.x;
        let u = hit.y;
        let b = hit.z;
        let pt = eye + t * dir;
        let y = clamp(0.5 + (uv.y - 0.5) * t, 0.0, 1.0);
        let edge_x = edge.x * dist / max(dist - edge.y, 1e-4);
        m = 1.0;
        if (aa > 0.0 && u > select(0.5 * w, straight, curled)) { m = clamp(abs(x - edge_x) / aa, 0.0, 1.0); }
        let normal = vec2f(-sin(b), cos(b));
        let front = dot(normal, eye - pt) > 0.0;
        if (front) {
            img = from_color(vec2f(clamp(w + u, w, ratio) / ratio, y));
        } else {
            img = to_color(vec2f(clamp(w - u, 0.0, w) / ratio, y));
        }
        let diffuse = max(dot(select(-normal, normal, front), LIGHT), 0.0) / LIGHT.y;
        var shade = mix(1.0, 0.25 + 0.75 * diffuse, shading);
        shade *= 1.0 - 0.35 * shading * lift * exp(-u / (0.04 * w));
        img = vec4f(img.rgb * shade, img.a);
        if (m >= 1.0) { return img; }
    }
    var color = select(to_color(uv), from_color(uv), x < 0.0);
    let to_edge = edge - vec2f(x, 0.0);
    let cos_edge = to_edge.x / max(length(to_edge), 1e-6);
    let blocked = 0.5 * abs(select(-1.0, 1.0, x < 0.0) - cos_edge);
    var shadow = blocked * blocked * (3.0 - 2.0 * blocked);
    let slope = -LIGHT.x / LIGHT.y;
    let reach = vec3f(bend.x, middle.x, edge.x) + slope * vec3f(bend.y, middle.y, edge.y);
    let lo = min(0.0, min(reach.x, min(reach.y, reach.z)));
    let hi = max(0.0, max(reach.x, max(reach.y, reach.z)));
    let soft = max(0.25 * edge.y, 1e-5);
    shadow = max(0.5 * shadow, 0.85 * clamp(min(x - lo, hi - x) / soft + 0.5, 0.0, 1.0) * min(4.0 * lift, 1.0));
    color = vec4f(color.rgb * (1.0 - shading * shadow), color.a);
    return mix(color, img, m);
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
