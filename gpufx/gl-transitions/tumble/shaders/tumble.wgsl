// Port of Tumble.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Tumble.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const EDGE: f32 = 0.0015;
// Direction toward the light: above, to the right, in front.
const LIGHT: vec3f = vec3f(0.348, 0.696, -0.628);

fn roll(v: vec3f, c: f32, s: f32) -> vec3f {
    return vec3f(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}

fn card_distance(q: vec2f, ratio: f32) -> f32 {
    let e = abs(q) - vec2f(0.5 * ratio, 0.5);
    return max(e.x, e.y);
}

// Casts the ray d from the eye onto the card's plane, rel being the card's center from the eye:
// (the point hit in the card's axes, the distance along d), or a negative distance when it misses.
fn cast_on_card(d: vec3f, rel: vec3f, u: vec3f, v: vec3f, n: vec3f) -> vec3f {
    let dn = dot(d, n);
    if (abs(dn) < 1e-6) { return vec3f(0.0, 0.0, -1.0); }
    let k = dot(rel, n) / dn;
    let h = k * d - rel;
    return vec3f(dot(h, u), dot(h, v), k);
}

fn card_uv(q: vec2f, ratio: f32) -> vec2f {
    return clamp(vec2f(q.x / ratio, q.y) + 0.5, vec2f(0.0), vec2f(1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let shading = params.shading;
    let t = clamp(progress / 0.95, 0.0, 1.0);
    let size = exp(-2.8 * t * t * (0.4 + 0.6 * t));
    let away = 1.0 - size;
    let turn = t * t * (3.0 - 2.0 * t);
    let a = 2.0 * PI * params.flips * turn;
    let r = 2.0 * PI * params.spin * turn;
    let cr = cos(r);
    let sr = sin(r);
    // End over end around its horizontal axis, then around the line of sight.
    let U = roll(vec3f(1.0, 0.0, 0.0), cr, sr);
    let V = roll(vec3f(0.0, cos(a), sin(a)), cr, sr);
    let N = roll(vec3f(0.0, -sin(a), cos(a)), cr, sr);

    // The camera, at dist in front of the plane z = 0, sees the frame at rest on it.
    let dist = 1.0 / clamp(params.perspective, 0.1, 1.0);
    let seen = params.direction * away + vec2f(0.0, 0.12 * t * (1.0 - t));
    let rel = vec3f(seen / size, dist / size);
    let fade = 1.0 - smoothstep(0.8, 1.0, t);
    let shadow_amount = 0.6 * shading * sqrt(size) * fade;

    let p = vec2f((uv.x - 0.5) * ratio, uv.y - 0.5);
    var color = to_color(uv);

    if (shadow_amount > 0.0) {
        let ds = vec3f(p - vec2f(-0.05, -0.08) * min(4.0 * t, 1.0) * size, dist);
        let hs = cast_on_card(ds, rel, U, V, N);
        if (hs.z > 0.0) {
            let blur = 0.005 + 0.06 * min(3.0 * t, 1.0) * size;
            let sd = card_distance(hs.xy, ratio) * max(abs(dot(ds, N)) / length(ds), 0.05) / hs.z;
            let sh = (1.0 - smoothstep(-blur, blur, sd)) * from_color(card_uv(hs.xy, ratio)).a;
            color = vec4f(color.rgb * (1.0 - shadow_amount * sh), color.a);
        }
    }

    let d = vec3f(p, dist);
    let hit = cast_on_card(d, rel, U, V, N);
    if (hit.z <= 0.0) { return color; }
    let dn = dot(d, N);
    // Antialiased edges: a screen pixel covers more of the card when it is far or seen at a grazing angle.
    let grazing = max(abs(dn) / length(d), 0.05);
    let e = EDGE * min(20.0 * t, 1.0) * hit.z / grazing;
    let m = clamp(0.5 - card_distance(hit.xy, ratio) / max(e, 1e-6), 0.0, 1.0) * fade;
    if (m <= 0.0) { return color; }

    var card = from_color(card_uv(hit.xy, ratio));
    // The side facing the camera: the front, or the back which shows the picture through, darker and duller.
    let front = dn > 0.0;
    let facing = select(N, -N, front);
    let lit = min((0.35 + 0.65 * max(dot(facing, LIGHT), 0.0)) / (0.35 + 0.65 * -LIGHT.z), 1.0);
    let shade = mix(1.0, lit * select(0.55, 1.0, front), shading);
    var rgb = card.rgb;
    if (!front) { rgb = mix(rgb, vec3f(dot(rgb, vec3f(0.299, 0.587, 0.114))), 0.4 * shading); }
    let glint = pow(max(dot(facing, normalize(LIGHT - normalize(d))), 0.0), 60.0);
    rgb = rgb * shade + 0.35 * shading * glint * smoothstep(0.0, 0.2, t);
    card = vec4f(rgb, card.a);
    if (m >= 1.0) { return card; }
    // Blended premultiplied, so that a transparent layer gives no color to the other one.
    let mixed = mix(vec4f(color.rgb * color.a, color.a), vec4f(card.rgb * card.a, card.a), m);
    if (mixed.a > 0.0) { return vec4f(mixed.rgb / mixed.a, mixed.a); }
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
