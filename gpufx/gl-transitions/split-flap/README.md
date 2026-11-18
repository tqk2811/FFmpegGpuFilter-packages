# Split Flap

The frame becomes a split-flap board: in each cell the top half of the first clip flips down on a hinge across the middle, cell after cell, its back bringing the bottom half of the second clip. Drive `progress` from 0 to 1.

Port of [`SplitFlap.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SplitFlap.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by gre, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `split-flap.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `columns` | int | `8` | 1 to 40 | Number of cell columns |
| `rows` | int | `6` | 1 to 40 | Number of cell rows |
| `stagger` | float | `0.6` | 0 to 0.9 | Delay of the last cell's flip, as a part of the transition |
| `randomness` | float | `0.3` | 0 to 1 | How much the order of the cells is shuffled, from a wave across the board to random |
| `flaps` | int | `1` | 1 to 4 | Number of flaps that fall in each cell, the ones before the last showing other parts of the second clip |
| `gap` | float | `0.004` | 0 to 0.05 | Width of the gaps between the cells, as a part of the frame's shorter side |
| `perspective` | float | `0.35` | 0 to 1 | Amount of perspective: the falling flaps grow as they come toward the viewer |
| `shading` | float | `0.4` | 0 to 1 | How much the flaps darken as they turn away from the light, and their shadows |
| `background` | color | `#000000` | - | Color seen in the gaps between the cells |

A `color` is `#rrggbb` or `#rrggbbaa`, or `r,g,b[,a]` from 0 to 1.

An `int` is rounded to the nearest whole number.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='split-flap.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='split-flap.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
