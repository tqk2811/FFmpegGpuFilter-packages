# Shutter Wipe

A camera's focal-plane shutter fires across the frame seen through the camera's gate: metal blades fan down until they cover the frame, then run on and stack below it, uncovering the second clip from the top. Drive `progress` from 0 to 1.

Port of [`ShutterWipe.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/ShutterWipe.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by gre, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `shutter-wipe.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `blades` | int | `5` | 3 to 10 | Number of metal blades |
| `tilt` | float | `0.06` | 0 to 0.2 | How much the blades tilt on their arms while they travel |
| `gate` | float | `0.035` | 0 to 0.08 | Width of the camera's gate framing the picture while the shutter fires, in frame heights |
| `color` | color | `#17171a` | - | Color of the metal blades |

A `color` is `#rrggbb` or `#rrggbbaa`, or `r,g,b[,a]` from 0 to 1.

An `int` is rounded to the nearest whole number.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='shutter-wipe.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='shutter-wipe.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
