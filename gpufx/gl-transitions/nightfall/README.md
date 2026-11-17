# Nightfall

Night crosses the frame like the shadow line of a turning globe: a warm dusk dims the first clip into blue moonlight, then a rose dawn brings up the daylight on the second. Drive `progress` from 0 to 1.

Port of [`Nightfall.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/Nightfall.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by gre, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `nightfall.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `direction` | vec2 | `1.0, 0.2` | - | Direction the night travels toward (x right, y up) |
| `night` | float | `0.7` | 0.2 to 1.2 | Width of the night between dusk and dawn, in frame heights |
| `darkness` | float | `0.8` | 0 to 1 | How dark the night gets |
| `bow` | float | `0.5` | -1 to 1 | Bow of the dusk and dawn lines |
| `dusk` | color | `#ff853d` | - | Light of the setting sun along the dusk line |
| `dawn` | color | `#ffa89e` | - | Light of the rising sun along the dawn line |
| `moon` | color | `#6b8fff` | - | Tint of the moonlight in the night |

A `vec2` is two comma-separated numbers (`center=0.3,0.6`; write `0.3\,0.6` in an FFmpeg command line).

A `color` is `#rrggbb` or `#rrggbbaa`, or `r,g,b[,a]` from 0 to 1.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='nightfall.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='nightfall.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
