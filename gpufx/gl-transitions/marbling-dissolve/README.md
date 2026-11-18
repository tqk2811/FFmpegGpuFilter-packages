# Marbling Dissolve

The second clip floats onto the first in thin bands of ink that a rake drags into zigzags and a fine comb pulls into feathers, like marbled paper; the bands widen until they cover the frame and the combs pull back out, leaving the second clip clean. Drive `progress` from 0 to 1.

Port of [`MarblingDissolve.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/MarblingDissolve.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by gre, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `marbling-dissolve.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `tines` | float | `6.0` | 2 to 16 | Number of teeth of the rake dragged up and down, along the longer side of the frame |
| `pull` | float | `0.12` | 0 to 0.2 | How far the teeth of the rake drag the picture, in frame heights (the fine comb drags it 0.6 times as far) |
| `bands` | float | `12.0` | 3 to 30 | Number of bands of ink across the frame |
| `veins` | float | `0.5` | 0 to 1 | How dark the thin lines of ink between the two clips are |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='marbling-dissolve.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='marbling-dissolve.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
