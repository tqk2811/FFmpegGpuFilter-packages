# Slit Stretch

The first clip is a sheet cut with rows of staggered slits that is pulled from both ends: it lengthens, the slits open into diamonds and the strands between them twist and thin out like expanded metal until only the second clip is left behind. Drive `progress` from 0 to 1.

Port of [`SlitStretch.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/SlitStretch.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by gre, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `slit-stretch.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `size` | float | `0.16` | 0.05 to 0.4 | Length of a slit and its bridge, relative to the frame height |
| `stretch` | float | `1.6` | 0 to 3 | How much the sheet lengthens as it is pulled |
| `shading` | float | `0.7` | 0 to 1 | Strength of the shading of the twisting strands and of their shadow |
| `neck` | float | `0.8` | 0 to 1 | How much the sheet narrows at its waist as it is pulled |
| `horizontal` | bool | `false` | - | Pull the sheet sideways instead, with vertical slits |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='slit-stretch.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='slit-stretch.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
