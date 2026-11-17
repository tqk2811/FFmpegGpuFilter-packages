# Normalize

Stretches each frame's R, G and B range to the black and white points, like FFmpeg's `normalize` without temporal smoothing.

## Inputs

- `src`: Picture to normalize.

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `normalize.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `blackpt` | color | `#000000` |  | Output color the darkest input value of each channel is mapped to |
| `whitept` | color | `#ffffff` |  | Output color the brightest input value of each channel is mapped to |
| `independence` | float | `1.0` | 0.0 to 1.0 | Proportion of per-channel to linked normalization: 0 stretches the three channels together, 1 each on its own |
| `strength` | float | `1.0` | 0.0 to 1.0 | Strength, from no change (0) to full normalization (1) |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='normalize.zip=independence=0.5&strength=0.8',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='normalize.zip=independence=0.5&strength=0.8',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'normalize.zip=independence=0.5&strength=0.8' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `normalize` (`vf_normalize.c`). For each channel the minimum and maximum of the frame are found; `independence` mixes them with the range of all three channels together, `strength` mixes the black and white points with the input range, and each value is mapped linearly with FFmpeg's rounding (`(int)(x * scale + offset + 0.5)`, clipped). Alpha is passed through.

The frame minimum and maximum take three passes: one thread per row and statistic, then one per statistic over the rows, then the mapping. The values go between passes as the 32 bits of an `f32` in the four 8-bit channels of a texel. The picture must be at least 6 pixels wide.

Checked against FFmpeg's `normalize` on the test picture and on a low-contrast copy, with the defaults, `independence=0`, `independence=0.3`/`0.5` and `strength=0.5`/`0.7`, and with other black and white points: at most 1 8-bit level apart (mean 0 to 0.5).

Differences from FFmpeg:

- `smoothing` (a running average of the range over the previous frames) is not ported, because effects keep no state between frames; it behaves as `smoothing=0`.
- Values are handled as 8-bit codes, also for video with more bits.
