// Port of InvertedPageCurl.glsl from gl-transitions.
// https://github.com/gl-transitions/gl-transitions/blob/master/transitions/InvertedPageCurl.glsl
//
// Copyright (c) 2010 Hewlett-Packard Development Company, L.P. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//      copyright notice, this list of conditions and the following disclaimer
//      in the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of Hewlett-Packard nor the names of its
//      contributors may be used to endorse or promote products derived from
//      this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// The code below works in gl-transitions coordinates (origin bottom left, y up);
// `from_color` and `to_color` flip back to the texture.

fn from_color(p: vec2f) -> vec4f { return textureSampleLevel(first, smp, vec2f(p.x, 1.0 - p.y), 0.0); }
fn to_color(p: vec2f) -> vec4f { return textureSampleLevel(second, smp, vec2f(p.x, 1.0 - p.y), 0.0); }

const MIN_AMOUNT: f32 = -0.4;
const MAX_AMOUNT: f32 = 1.5;
const PI: f32 = 3.141592653589793;
const SCALE: f32 = 512.0;
const SHARPNESS: f32 = 3.0;
const CYLINDER_RADIUS: f32 = 1.0 / PI / 2.0;

var<private> amount: f32;
var<private> cylinder_center: f32;
var<private> cylinder_angle: f32;

fn glsl_mod(x: f32, y: f32) -> f32 { return x - y * floor(x / y); }

fn hit_point(hit_angle: f32, point_in: vec3f, rrotation: mat3x3f) -> vec3f {
    var point = point_in;
    point.y = hit_angle / (2.0 * PI);
    return rrotation * point;
}

fn anti_alias(color1: vec4f, color2: vec4f, distance_in: f32) -> vec4f {
    let distanc = distance_in * SCALE;
    if (distanc < 0.0) { return color2; }
    if (distanc > 2.0) { return color1; }
    let dd = pow(1.0 - distanc / 2.0, SHARPNESS);
    return ((color2 - color1) * dd) + color1;
}

fn distance_to_edge(point: vec3f) -> f32 {
    var dx = abs(select(point.x, 1.0 - point.x, point.x > 0.5));
    var dy = abs(select(point.y, 1.0 - point.y, point.y > 0.5));
    if (point.x < 0.0) { dx = -point.x; }
    if (point.x > 1.0) { dx = point.x - 1.0; }
    if (point.y < 0.0) { dy = -point.y; }
    if (point.y > 1.0) { dy = point.y - 1.0; }
    if ((point.x < 0.0 || point.x > 1.0) && (point.y < 0.0 || point.y > 1.0)) { return sqrt(dx * dx + dy * dy); }
    return min(dx, dy);
}

fn see_through(yc: f32, p: vec2f, rotation: mat3x3f, rrotation: mat3x3f) -> vec4f {
    let hit_angle = PI - (acos(clamp(yc / CYLINDER_RADIUS, -1.0, 1.0)) - cylinder_angle);
    let point = hit_point(hit_angle, rotation * vec3f(p, 1.0), rrotation);
    if (yc <= 0.0 && (point.x < 0.0 || point.y < 0.0 || point.x > 1.0 || point.y > 1.0)) {
        return to_color(p);
    }
    if (yc > 0.0) { return from_color(p); }
    let color = from_color(point.xy);
    return anti_alias(color, vec4f(0.0), distance_to_edge(point));
}

fn see_through_with_shadow(yc: f32, p: vec2f, point: vec3f, rotation: mat3x3f, rrotation: mat3x3f) -> vec4f {
    var shadow = distance_to_edge(point) * 30.0;
    shadow = (1.0 - shadow) / 3.0;
    if (shadow < 0.0) { shadow = 0.0; } else { shadow *= amount; }
    let c = see_through(yc, p, rotation, rrotation);
    return vec4f(c.rgb - shadow, c.a);
}

fn backside(yc: f32, point: vec3f) -> vec4f {
    let color = from_color(point.xy);
    var gray = (color.r + color.b + color.g) / 15.0;
    gray += (8.0 / 10.0) * (pow(max(0.0, 1.0 - abs(yc / CYLINDER_RADIUS)), 2.0 / 10.0) / 2.0 + (5.0 / 10.0));
    return vec4f(vec3f(gray), color.a);
}

fn behind_surface(p: vec2f, yc_in: f32, point_in: vec3f, rrotation: mat3x3f) -> vec4f {
    let safe_amount = select(min(amount, -1e-4), max(amount, 1e-4), amount >= 0.0);
    var shado = (1.0 - ((-CYLINDER_RADIUS - yc_in) / safe_amount * 7.0)) / 6.0;
    shado *= 1.0 - abs(point_in.x - 0.5);

    let yc = -CYLINDER_RADIUS - CYLINDER_RADIUS - yc_in;
    let hit_angle = (acos(clamp(yc / CYLINDER_RADIUS, -1.0, 1.0)) + cylinder_angle) - PI;
    let point = hit_point(hit_angle, point_in, rrotation);

    if (yc < 0.0 && point.x >= 0.0 && point.y >= 0.0 && point.x <= 1.0 && point.y <= 1.0 && (hit_angle < PI || amount > 0.5)) {
        let dx = point.x - 0.5;
        let dy = point.y - 0.5;
        shado = 1.0 - (sqrt(dx * dx + dy * dy) / (71.0 / 100.0));
        let nyc = -yc / CYLINDER_RADIUS;
        shado *= nyc * nyc * nyc;
        shado *= 0.5;
    } else {
        shado = 0.0;
    }
    let to = to_color(p);
    return vec4f(to.rgb - shado, to.a);
}

fn transition(p: vec2f, progress: f32) -> vec4f {
    amount = progress * (MAX_AMOUNT - MIN_AMOUNT) + MIN_AMOUNT;
    cylinder_center = amount;
    cylinder_angle = 2.0 * PI * amount;

    let angle = 100.0 * PI / 180.0;
    var c = cos(-angle);
    var s = sin(-angle);
    // Column major, as GLSL's mat3 constructor.
    let rotation = mat3x3f(c, s, 0.0, -s, c, 0.0, -0.801, 0.8900, 1.0);
    c = cos(angle);
    s = sin(angle);
    let rrotation = mat3x3f(c, s, 0.0, -s, c, 0.0, 0.98500, 0.985, 1.0);

    var point = rotation * vec3f(p, 1.0);
    let yc = point.y - cylinder_center;

    if (yc < -CYLINDER_RADIUS) { return behind_surface(p, yc, point, rrotation); }
    if (yc > CYLINDER_RADIUS) { return from_color(p); }

    let hit_angle = (acos(clamp(yc / CYLINDER_RADIUS, -1.0, 1.0)) + cylinder_angle) - PI;
    let hit_angle_mod = glsl_mod(hit_angle, 2.0 * PI);
    if ((hit_angle_mod > PI && amount < 0.5) || (hit_angle_mod > PI / 2.0 && amount < 0.0)) {
        return see_through(yc, p, rotation, rrotation);
    }

    point = hit_point(hit_angle, point, rrotation);
    if (point.x < 0.0 || point.y < 0.0 || point.x > 1.0 || point.y > 1.0) {
        return see_through_with_shadow(yc, p, point, rotation, rrotation);
    }

    var color = backside(yc, point);
    var other_color: vec4f;
    if (yc < 0.0) {
        let dx2 = point.x - 0.5;
        let dy2 = point.y - 0.5;
        var shado = 1.0 - (sqrt(dx2 * dx2 + dy2 * dy2) / 0.71);
        let nyc2 = -yc / CYLINDER_RADIUS;
        shado *= nyc2 * nyc2 * nyc2;
        shado *= 0.5;
        other_color = vec4f(0.0, 0.0, 0.0, shado * to_color(p).a);
    } else {
        other_color = from_color(p);
    }
    color = anti_alias(color, other_color, CYLINDER_RADIUS - abs(yc));

    let cl = see_through_with_shadow(yc, p, point, rotation, rrotation);
    return anti_alias(color, cl, distance_to_edge(point));
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
