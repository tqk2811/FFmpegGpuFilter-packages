# Glitch Flicker

A flickering glitch with RGB offset, ghosting and scanlines that flashes back to the first clip. Drive `progress` from 0 to 1.

Port of [`GlitchFlicker.glsl`](https://github.com/gl-transitions/gl-transitions/blob/master/transitions/GlitchFlicker.glsl) from [gl-transitions](https://github.com/gl-transitions/gl-transitions), by bread, under the MIT license (see [LICENSE](LICENSE)). The shader is rewritten in WGSL; it keeps the original's coordinates (y up) and shows the exact clips at `progress` 0 and 1.

## Inputs

- `first`: Outgoing clip
- `second`: Incoming clip (must have the same size as the first input)

## Output

Same size as the first input (`first`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `glitch-flicker.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `progress` | float | `0.5` | 0 to 1 | 0 = first clip, 1 = second clip |
| `frame_rate` | float | `24.0` | 6 to 60 | Rate at which the glitch steps through its frames, per unit of progress |
| `rgb_offset` | float | `0.014` | 0 to 0.05 | Distance between the red and blue channels, as a part of the frame width |
| `block_amount` | float | `0.72` | 0 to 1 | How much the blocks break up the reveal |
| `ghost_amount` | float | `0.62` | 0 to 1 | Strength of the flashes back to the first clip |
| `red_cyan` | float | `0.58` | 0 to 1 | Strength of the red and cyan ghost washes |
| `scanline` | float | `0.075` | 0 to 0.3 | Strength of the scanlines |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='glitch-flicker.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=yuv420p" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i a.mp4 -i b.mp4 -filter_complex \
  "[0][1]gpufx=graph='glitch-flicker.zip=progress=clip((t-1)/1.5\,0\,1)',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).
