// Port of CardDeal.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/CardDeal.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const PI: f32 = 3.141592653589793;
const MAX_CARDS: i32 = 36;
// Time between two cards, relative to the time a card takes from the deck to its place.
const DEAL: f32 = 0.16;
// Part of its way after which a card touches down and starts sliding.
const TOUCH: f32 = 0.55;
const THROW: f32 = 2.2;
const SLIDE: f32 = 0.35;
// Highest point of a card's flight, and distance of the eye to the table, in frame heights.
const LIFT: f32 = 0.45;
const EYE: f32 = 2.4;
const EDGE: f32 = 0.0015;

fn hash(n: f32) -> f32 {
    var p = fract(vec2f(n) * vec2f(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}

// Local time of card j: 0 on the deck, 1 once it lies still in its place.
fn card_time(j: f32, n: f32, progress: f32) -> f32 {
    let flight = 1.0 / (1.0 + (n - 1.0) * DEAL);
    return clamp((progress - j * DEAL * flight) / flight, 0.0, 1.0);
}

fn card_cell(j: f32, g: vec2f) -> vec2f {
    let row = floor(j / g.x);
    return vec2f(j - row * g.x, g.y - 1.0 - row);
}

fn card_dist(q: vec2f, size: vec2f) -> f32 {
    let e = min(q, 1.0 - q) * size;
    return min(e.x, e.y);
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    // The original's ivec2 grid is split into two options here.
    let g = clamp(vec2f(f32(params.columns), f32(params.rows)), vec2f(1.0), vec2f(6.0));
    let n = g.x * g.y;
    let asp = vec2f(ratio, 1.0);
    let size = asp / g;
    let p = uv * asp;
    let origin = vec2f(params.deck.x, 1.0 - params.deck.y) * asp;
    let darkness = clamp(params.shadow, 0.0, 1.0);

    let own = min(floor(uv * g), g - 1.0);
    let own_index = (g.y - 1.0 - own.y) * g.x + own.x;
    var col = from_color(uv);
    if (card_time(own_index, n, progress) >= 1.0) { col = to_color(uv); }

    // The cards on their way, from the first dealt to the last: later cards lie on top.
    for (var i = 0; i < MAX_CARDS; i++) {
        let j = f32(i);
        if (j >= n) { break; }
        let u = card_time(j, n, progress);
        if (u <= 0.0) { break; }
        if (u >= 1.0) { continue; }

        let cell = card_cell(j, g);
        let target_p = (cell + 0.5) * size;
        let way = target_p - origin;
        let len = max(length(way), 1e-3);
        let side = vec2f(-way.y, way.x);
        let r1 = hash(j + 1.0);
        let r2 = hash(j + 60.0);
        let turn = select(1.0, -1.0, r2 < 0.5);
        let slide = min(SLIDE * size.y / len, 0.5);
        let a = min(u / TOUCH, 1.0);
        let s = clamp((u - TOUCH) / (1.0 - TOUCH), 0.0, 1.0);
        // The flight ends at the speed the slide starts with.
        let v1 = 2.0 * slide * TOUCH / ((1.0 - TOUCH) * (1.0 - slide));
        let f = (3.0 - 2.0 * a) * a * a + THROW * (a * a * a - 2.0 * a * a + a) + v1 * (a * a * a - a * a);
        var e = 1.0 - slide * (1.0 - s) * (1.0 - s);
        if (u < TOUCH) { e = (1.0 - slide) * f; }
        let c = origin + way * e + side * turn * (0.05 + 0.05 * r1) * sin(PI * e);
        let h = LIFT * (0.7 + 0.3 * r1) * sin(PI * a) * (1.0 - 0.35 * a);
        let angle = turn * params.spin * (0.8 + 0.4 * r2) * 2.0 * PI * (1.0 - e);
        let tilt = 0.45 * sin(PI * a) * cos(angle * 0.5 + 6.0 * r1);
        let air = 1.0 - a * a;
        let fade = smoothstep(0.0, 0.05, u);

        let sp = p - c - vec2f(0.18, -0.3) * h - vec2f(0.002, -0.003);
        let ca = cos(angle);
        let sa = sin(angle);
        let rot = mat2x2f(ca, -sa, sa, ca);
        let sq = rot * sp / size + 0.5;
        let soft = 0.006 + 0.08 * h;
        let sh = smoothstep(-soft, soft, card_dist(sq, size));
        let dark = mix(0.8 * (1.0 - s), 0.65 - 0.3 * h / LIFT, air);
        col = vec4f(col.rgb * (1.0 - fade * darkness * dark * sh), col.a);

        let d = rot * (p - c) * (EYE - h) / EYE;
        let ct = cos(tilt);
        let st = sin(tilt);
        // Past the horizon of the tilted card, the point is off the card.
        let den = EYE * ct + d.y * st;
        var k = 1e3;
        if (den > 1e-3) { k = EYE * ct / den; }
        let q = vec2f(k * d.x, k * d.y * ct + EYE * (1.0 - k) * st) / size + 0.5;
        // Its edges sharpen as it comes to rest, to meet its neighbors without a seam.
        let edge = EDGE * (1.0 + 2.0 * air) * min(10.0 * (1.0 - s), 1.0);
        let m = fade * clamp(card_dist(q, size) / max(edge, 1e-6) + 0.5, 0.0, 1.0);
        if (m > 0.0) {
            let face0 = to_color((cell + clamp(q, vec2f(0.0), vec2f(1.0))) / g);
            let light = 1.0 + 0.6 * st * (0.6 - 0.4 * turn * sin(angle));
            let rim = 1.0 - smoothstep(0.0, 0.008, card_dist(q, size));
            let face = vec4f(mix(min(face0.rgb * light, vec3f(face0.a)), vec3f(face0.a), 0.45 * air * rim), face0.a);
            col = mix(col, face, m);
        }
    }
    return col;
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
