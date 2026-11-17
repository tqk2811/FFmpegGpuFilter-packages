# Revolve

The picture swirls and zooms with motion blur into the second clip. Drive `progress` from 0 to 1.

Port of [`Revolve.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Revolve.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by bread, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `revolve.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `center` | vec2 | `0.46, 0.48` | - | Center of the swirl (0..1, y down) |
| `direction` | float | `-1.0` | -1 to 1 | Direction of the turn (1 or -1) |
| `max_rotation` | float | `1.95` | 0 to 6.3 | Turn of the edges at the peak, in radians |
| `peak_zoom` | float | `2.22` | 1 to 5 | Zoom at the peak |
| `swirl` | float | `2.85` | 0 to 10 | Extra turn at the center, in radians |
| `barrel` | float | `0.38` | 0 to 1 | Barrel distortion at the peak |
| `motion_blur` | float | `1.0` | 0 to 3 | Amount of motion blur |
| `switch_start` | float | `0.3` | 0 to 1 | Progress at which the switch to the second clip starts |
| `switch_end` | float | `0.5` | 0 to 1 | Progress at which the switch ends |
| `shadow` | float | `0.16` | 0 to 1 | Darkening of the edges at the peak |

A `vec2` is two comma-separated numbers (`center=0.3,0.6`; write `0.3\,0.6` in an FFmpeg command line).

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='revolve.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='revolve.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
