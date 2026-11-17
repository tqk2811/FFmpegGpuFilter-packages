// Port of GlitchDisplace.glsl from gl-transitions (author: Matt DesLauriers, license: MIT).
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchDisplace.glsl
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

fn glsl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn random(co: vec2f) -> f32 {
    let dt = dot(co, vec2f(12.9898, 78.233));
    let sn = glsl_mod(dt, 3.14);
    return fract(sin(sn) * 43758.5453);
}

fn voronoi(x: vec2f) -> f32 {
    let p = floor(x);
    let f = fract(x);
    var res = 8.0;
    for (var j = -1.0; j <= 1.0; j += 1.0) {
        for (var i = -1.0; i <= 1.0; i += 1.0) {
            let b = vec2f(i, j);
            let r = b - f + random(p + b);
            res = min(res, dot(r, r));
        }
    }
    return sqrt(res);
}

// The original also computes three voronoi values here that it never uses; they are left out.
fn displace(tex: vec4f, tex_coord: vec2f, dot_depth: f32, texture_depth: f32, strength: f32) -> vec2f {
    let dis = tex * dot_depth + 1.0 - tex * texture_depth;
    let dx = (dis.x - 1.0 + texture_depth * dot_depth) * strength;
    let dy = (dis.y - 1.0 + texture_depth * dot_depth) * strength;
    return tex_coord + vec2f(dx, dy);
}

fn ease1(t: f32) -> f32 {
    if (t == 0.0 || t == 1.0) { return t; }
    if (t < 0.5) { return 0.5 * pow(2.0, (20.0 * t) - 10.0); }
    return -0.5 * pow(2.0, 10.0 - (t * 20.0)) + 1.0;
}

fn ease2(t: f32) -> f32 {
    if (t == 1.0) { return t; }
    return 1.0 - pow(2.0, -10.0 * t);
}

fn transition(p: vec2f, progress: f32) -> vec4f {
    var color1 = from_color(p);
    var color2 = to_color(p);
    let disp = displace(color1, p, 0.33, 0.7, 1.0 - ease1(progress));
    let disp2 = displace(color2, p, 0.33, 0.5, ease2(progress));
    let d_color1 = to_color(disp);
    var d_color2 = from_color(disp2);
    let val = ease1(progress);
    let gray = vec3f(dot(min(d_color2, d_color1).rgb, vec3f(0.299, 0.587, 0.114)));
    d_color2 = vec4f(gray * 2.0, d_color2.a);
    color1 = mix(color1, d_color2, smoothstep(0.0, 0.5, progress));
    color2 = mix(color2, d_color1, smoothstep(1.0, 0.5, progress));
    return mix(color1, color2, val);
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
