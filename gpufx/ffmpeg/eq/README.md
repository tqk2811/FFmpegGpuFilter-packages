# Eq

Adjusts brightness, contrast, saturation and gamma the way FFmpeg's `eq` filter does.

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `eq.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `contrast` | float | `1` | -1000 to 1000 | Contrast of the luma around its middle |
| `brightness` | float | `0` | -1 to 1 | Value added to the luma |
| `saturation` | float | `1` | 0 to 3 | Gain of the chroma (0 = gray) |
| `gamma` | float | `1` | 0.1 to 10 | Gamma of the luma |
| `gamma_r` | float | `1` | 0.1 to 10 | Gamma for red (applied to Cr) |
| `gamma_g` | float | `1` | 0.1 to 10 | Gamma for green (applied to the luma and both chroma) |
| `gamma_b` | float | `1` | 0.1 to 10 | Gamma for blue (applied to Cb) |
| `gamma_weight` | float | `1` | 0 to 1 | How much of the gamma curve is used (0 = none) |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='eq.zip=contrast=1.3&brightness=0.05&saturation=1.5',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='eq.zip=contrast=1.3&brightness=0.05&saturation=1.5',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'eq.zip=contrast=1.3&brightness=0.05&saturation=1.5' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `eq` (`vf_eq.c`). One pass: the RGB picture is turned into BT.709 limited-range Y'CbCr, and each plane goes through FFmpeg's curve `v = contrast * (x - 0.5) + 0.5 + brightness`, then `v * (1 - gamma_weight) + v^(1/gamma) * gamma_weight`, clamped to 0..1. The luma uses `contrast`, `brightness` and `gamma * gamma_g`; Cb uses `saturation` as its contrast and `sqrt(gamma_b / gamma_g)`, Cr `saturation` and `sqrt(gamma_r / gamma_g)`, as in FFmpeg. The result goes back to RGB; alpha is passed through.

Checked against FFmpeg's `eq` run on BT.709 limited-range `yuv444p`: at most a few 8-bit levels apart (FFmpeg rounds each plane to 8 bits; this port does not).

Differences from FFmpeg:

- FFmpeg works on the planes of the stream as they are (its matrix and range); gpufx hands the shader RGB, so the port always uses BT.709 limited range. On BT.601 or full-range video the result differs slightly from FFmpeg's.
- The curve is computed in floating point instead of through an 8-bit table, so it also keeps more than 8 bits.
- The `eval` option is not ported: every value may change on every frame.
