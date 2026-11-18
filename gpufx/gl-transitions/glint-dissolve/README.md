# Glint Dissolve

The bright points of the first clip sparkle into crisp four-point star glints that swell and twinkle up to the cut, then shrink back into the highlights of the second clip, which stays sharp. Drive `progress` from 0 to 1.

Port of [`GlintDissolve.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlintDissolve.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by gre, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `glint-dissolve.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `size` | float | `0.15` | 0.02 to 0.3 | Length of the longest rays of the glints at the peak, in frame heights |
| `threshold` | float | `0.6` | 0 to 1 | Brightness above which the picture sparkles |
| `intensity` | float | `2.0` | 0 to 4 | Brightness of the glints |
| `diagonals` | bool | `false` | - | Add a shorter, softer pair of diagonal rays to each glint |
| `rotation` | float | `0.0` | -45 to 45 | Angle of the cross, in degrees |
| `rainbow` | float | `0.35` | 0 to 1 | Rainbow fringes along the rays |
| `tint` | color | `#fff2d9` | - | Tint of the glints, added as light |

A `color` is `#rrggbb` or `#rrggbbaa`, or `r,g,b[,a]` from 0 to 1.

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='glint-dissolve.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='glint-dissolve.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
