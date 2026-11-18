// Port of BlockSlide.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/BlockSlide.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const MAX_BLOCKS: i32 = 40;

fn hash(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn inside(l: vec2f) -> bool {
    return all(l >= vec2f(0.0)) && all(l < vec2f(1.0));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let direction = params.direction;
    let vertical = abs(direction.y) > abs(direction.x);
    let backward = select(direction.x < 0.0, direction.y < 0.0, vertical);
    let g = max(vec2f(f32(params.columns), f32(params.rows)), vec2f(1.0));
    var a = select(uv.x, uv.y, vertical);
    let b = select(uv.y, uv.x, vertical);
    if (backward) { a = 1.0 - a; }
    let n = min(select(g.x, g.y, vertical), f32(MAX_BLOCKS));
    let strips = select(g.y, g.x, vertical);
    // Every block of a strip slides along it, so a point can only show a block of its own strip.
    let r = min(floor(b * strips), strips - 1.0);
    var row_order = 0.0;
    if (strips > 1.0) { row_order = select(strips - 1.0 - r, r, vertical) / (strips - 1.0); }
    let st = clamp(params.stagger, 0.0, 0.95);
    let z = clamp(params.zoom, 0.0, 0.9);
    let an = a * n;
    let bn = b * strips - r;
    // The incoming blocks follow the rear outgoing block, so no block overlaps another.
    var rear = clamp((progress - st * mix(row_order, 1.0, 0.2)) / (1.0 - st), 0.0, 1.0);
    rear = rear * rear * (3.0 - 2.0 * rear);
    for (var k = 0; k < MAX_BLOCKS; k++) {
        let i = f32(k);
        if (i >= n) { break; }
        // The front block sets off first, so the outgoing blocks move apart.
        var o = 0.0;
        if (n > 1.0) { o = (n - 1.0 - i) / (n - 1.0); }
        let order = mix(row_order, o, 0.2);
        var p = clamp((progress - st * order) / (1.0 - st), 0.0, 1.0);
        p = p * p * (3.0 - 2.0 * p);
        let pin = max(0.0, 1.0 - (1.0 - rear) * (1.0 + (n - 1.0 - i) / n));
        let zi = select(0.0, z, hash(vec2f(i, r) + 3.7) < 0.5);
        let s_from = 1.0 - zi * p * p;
        let s_to = 1.0 - zi * (1.0 - pin) * (1.0 - pin);
        let lf = vec2f((an - i - p * n - 0.5 * (1.0 - s_from)) / s_from, (bn - 0.5 * (1.0 - s_from)) / s_from);
        let lt = vec2f((an - i - (pin - 1.0) * n - 0.5 * (1.0 - s_to)) / s_to, (bn - 0.5 * (1.0 - s_to)) / s_to);
        let in_from = inside(lf);
        let in_to = inside(lt);
        if (in_from || in_to) {
            var q = (vec2f(i, r) + select(lf, lt, in_to)) / vec2f(n, strips);
            if (backward) { q.x = 1.0 - q.x; }
            if (vertical) { q = q.yx; }
            return select(from_color(q), to_color(q), in_to);
        }
    }
    return params.background;
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
