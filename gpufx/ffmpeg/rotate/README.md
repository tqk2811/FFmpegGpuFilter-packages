# Rotate

Rotates the picture by any angle around its centre, like FFmpeg's `rotate` filter.

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

`ow` x `oh`: 0 is the input's side, -1 the side of the box holding the picture rotated by the starting `angle` (FFmpeg's `rotw(a)` and `roth(a)`, rounded). The size is computed once, when the filter is configured: `ow` and `oh` must not change while the stream runs, and with -1 neither may `angle`. With fixed sizes `angle` may change on every frame. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `rotate.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `angle` | float | `0` | -100000 to 100000 | Clockwise angle in radians (`a`) |
| `ow` | int | `0` | -1 to 16384 | Output width; 0 = the input's width, -1 = wide enough for the picture rotated by the starting angle (`rotw(a)`) |
| `oh` | int | `0` | -1 to 16384 | Output height; 0 = the input's height, -1 = tall enough for the picture rotated by the starting angle (`roth(a)`) |
| `fillcolor` | color | `#000000` |  | Colour of the area the picture does not cover (with alpha) |
| `bilinear` | bool | `1` | 0 or 1 | Bilinear interpolation; 0 = nearest pixel |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='rotate.zip=angle=PI/6',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='rotate.zip=angle=PI/6',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'rotate.zip=angle=PI/6' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `rotate` (`vf_rotate.c`). One pass: each output pixel reads the input at its position turned back by `angle` around the centres of both pictures, bilinear or nearest. As in FFmpeg, a position within one pixel outside the picture still reads the clamped edge pixel; farther ones get `fillcolor`. The `transform` package is a different effect (zoom and rotate keeping the size, angle in degrees).

Checked against FFmpeg's `rotate` with bilinear and nearest sampling, `rotw`/`roth` sizes and a fill colour: at most 1 8-bit level apart, except a handful of pixels on the picture's border where FFmpeg's 16.16 fixed-point positions fall on the other side of a pixel boundary.

Differences from FFmpeg:

- `angle`, `ow` and `oh` are numbers (or the FFmpeg expressions of the option), not `vf_rotate`'s own expressions; write `-1` for `rotw(a)`/`roth(a)`.
- `fillcolor` is `#rrggbb` or `#rrggbbaa`; FFmpeg's `none` (leave the area unpainted) is not ported, a transparent colour comes closest.
