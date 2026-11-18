# Strip Datamosh Glitch

A datamosh glitch: torn strips, chroma shifts and scan noise drag the first clip into the second one. Drive `progress` from 0 to 1.

Port of [`StripDatamoshGlitch.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/StripDatamoshGlitch.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by bread, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `strip-datamosh-glitch.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `strength` | float | `1.0` | 0 to 2 | Overall strength of the glitch |
| `horizontal_bars` | float | `42.0` | 4 to 120 | Number of horizontal bars across the frame's height |
| `vertical_slits` | float | `18.0` | 2 to 60 | Number of vertical slits across the frame's width |
| `tear` | float | `0.18` | 0 to 0.5 | How far the strips are torn sideways |
| `chroma` | float | `0.032` | 0 to 0.1 | Distance between the red and blue channels |
| `residue` | float | `0.62` | 0 to 1 | Strength of the smeared slices left in the torn strips |
| `noise_amount` | float | `0.16` | 0 to 0.5 | Strength of the noise |
| `scan_amount` | float | `0.13` | 0 to 0.5 | Strength of the scanlines |
| `flash_amount` | float | `0.2` | 0 to 1 | Brightness of the strobe flashes |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='strip-datamosh-glitch.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='strip-datamosh-glitch.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
