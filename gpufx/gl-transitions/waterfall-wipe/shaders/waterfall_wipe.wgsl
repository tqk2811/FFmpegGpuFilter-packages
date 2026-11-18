// Port of WaterfallWipe.glsl from gl-transitions (author: gre, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/WaterfallWipe.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const MAX_ROWS: i32 = 48;
// Time between two blocks of a column, as a part of the time a block takes to fall its own height.
const SPACING: f32 = 1.15;
// Time the edges and shadow of a block take to fade after its bounce, as a part of the frame's fall.
const SETTLE: f32 = 0.15;
// Speed the blocks are thrown in with, as a part of the speed they reach after a fall of the frame's height.
const THROW: f32 = 0.25;
const GROW: f32 = 0.06;
const EDGE: f32 = 0.0015;

fn box_dist(p: vec2f, b: vec2f) -> f32 {
    let d = abs(p) - b;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}

fn mirror(v: vec2f) -> vec2f {
    return 1.0 - abs(1.0 - abs(v));
}

fn transition(uv: vec2f, progress: f32) -> vec4f {
    let ratio = globals.size.x / globals.size.y;
    let nc = clamp(f32(params.columns), 1.0, 40.0);
    let nr = clamp(floor(nc / ratio + 0.5), 1.0, f32(MAX_ROWS));
    let cell = vec2f(ratio / nc, 1.0 / nr);
    let x = uv * vec2f(ratio, 1.0);
    let here = clamp(floor(uv.x * nc), 0.0, nc - 1.0);

    // The blocks start just above the frame, their grown size and antialiased edge included.
    let top = 1.0 + 0.5 * GROW * cell.y + 2.0 * EDGE;
    // Timing: g = 2 / u^2 is the gravity and 2 w / u the speed the blocks are thrown down with, so
    // a fall of height h takes u (sqrt(w^2 + h) - w); d is the time between two blocks of a column,
    // e the speed a block bounces back with, as a part of its landing speed. The top block of the
    // last column settles last, right at the end.
    var st = 0.0;
    if (nc > 1.0) { st = clamp(params.stagger, 0.0, 0.8); }
    let w = THROW;
    let e = 0.2 * clamp(params.bounce, 0.0, 1.0);
    let h_top = sqrt(w * w + top - (nr - 1.0) * cell.y);
    let dn = SPACING * (sqrt(w * w + cell.y) - w);
    let u = (1.0 - st) / (dn * (nr - 1.0) + h_top - w + 2.0 * e * h_top + SETTLE);
    let d = dn * u;
    let k = clamp(params.shadow, 0.0, 1.0);

    // The two highest blocks seen here (height, coverage, image point) and the shadow cast here.
    var z1 = -1.0;
    var z2 = -1.0;
    var m1 = 0.0;
    var m2 = 0.0;
    var a1 = 0.0;
    var a2 = 0.0;
    var shade = 0.0;
    var s1 = vec2f(0.0);
    var s2 = vec2f(0.0);
    let light = vec2f(0.35, -0.5) * min(cell.x, cell.y);
    for (var i = 0; i < 3; i++) {
        let c = here + f32(i) - 1.0;
        if (c < 0.0 || c >= nc) { continue; }
        var order = c;
        if (params.reverse != 0u) { order = nc - 1.0 - c; }
        var t0 = 0.0;
        if (nc > 1.0) { t0 = st * order / (nc - 1.0); }
        // The top of the block below, which the next block cannot go through.
        var floor_y = 0.0;
        for (var j = 0; j < MAX_ROWS; j++) {
            let r = f32(j);
            if (r >= nr) { break; }
            let slot = r * cell.y;
            let s = progress - t0 - r * d;
            // This block and the ones above it have not set off yet.
            if (s <= 0.0) { break; }
            let rh = sqrt(w * w + top - slot);
            let land = u * (rh - w);
            var y = top;
            var air = 1.0;
            if (s > land) {
                // It bounces back up with e times its landing speed, 2 rh / u.
                let b = s - land;
                y = slot + max(0.0, b * (2.0 * e * rh - b / u) / u);
                air = 1.0 - smoothstep(0.0, (2.0 * e * rh + SETTLE) * u, b);
            } else {
                y = top - s * (2.0 * w + s / u) / u;
            }
            y = max(y, floor_y);
            floor_y = y + cell.y;
            var z: f32;
            var cov: f32;
            var a: f32;
            var src: vec2f;
            if (air <= 0.0 && y - slot < 0.02 * cell.y) {
                // At rest in its slot: it fills its cell exactly.
                if (c != here || x.y < slot || x.y >= slot + cell.y || z2 >= 0.0) { continue; }
                z = 0.0;
                cov = 1.0;
                a = 0.0;
                src = uv;
            } else {
                let in_frame = clamp((1.0 - y) / cell.y, 0.0, 1.0);
                let center = vec2f((c + 0.5) * cell.x, y + 0.5 * cell.y);
                let sc = 1.0 + GROW * air;
                let q = (x - center) / sc;
                let blur = 0.002 + 0.3 * air * cell.y;
                let sd = box_dist(x - center - light * air, 0.5 * cell * sc);
                shade = max(shade, (1.0 - smoothstep(-blur, blur, sd)) * air * in_frame);
                let dist = box_dist(q, 0.5 * cell) * sc;
                // Antialiased while it falls; it sharpens as it settles, to tile with the blocks around it.
                let aa = EDGE * min(8.0 * air, 1.0);
                if (aa > 0.0) { cov = clamp(0.5 - dist / aa, 0.0, 1.0); } else { cov = step(dist, 0.0); }
                z = air + 0.001 * r;
                if (cov <= 0.0 || z <= z2) { continue; }
                src = (vec2f(c, r) * cell + q + 0.5 * cell) / vec2f(ratio, 1.0);
                let lq = q / (0.5 * cell);
                let bev = 1.0 - smoothstep(0.0, 0.12, -dist / min(cell.x, cell.y));
                a = air * bev * 0.5 * (lq.y - lq.x);
            }
            if (z > z1) {
                z2 = z1; m2 = m1; a2 = a1; s2 = s1;
                z1 = z; m1 = cov; a1 = a; s1 = src;
            } else {
                z2 = z; m2 = cov; a2 = a; s2 = src;
            }
        }
    }

    // The shadows fall on the first clip and on the blocks at rest, not on the moving ones.
    var col = from_color(uv);
    col = vec4f(col.rgb * (1.0 - 0.6 * k * shade), col.a);
    if (m2 > 0.0 && m1 < 1.0) {
        let b = to_color(mirror(s2));
        let rgb = clamp(b.rgb * (1.0 + 0.6 * k * a2) * (1.0 - 0.6 * k * shade * step(z2, 0.0)), vec3f(0.0), vec3f(1.0));
        col = mix(col, vec4f(rgb, b.a), m2);
    }
    if (m1 > 0.0) {
        let b = to_color(mirror(s1));
        let rgb = clamp(b.rgb * (1.0 + 0.6 * k * a1) * (1.0 - 0.6 * k * shade * step(z1, 0.0)), vec3f(0.0), vec3f(1.0));
        col = mix(col, vec4f(rgb, b.a), m1);
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
