# Vague Denoiser

Wavelet denoiser on a single frame, like FFmpeg's `vaguedenoiser`.

## Inputs

- `src`: Picture to denoise.

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `vaguedenoiser.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `threshold` | float | `2.0` | 0.0 to 255.0 | Filtering strength: coefficients up to this size are shrunk |
| `method` | enum | `garrote` | `hard`, `soft`, `garrote` | Shrinking of the coefficients above the threshold: kept, moved toward 0 by the threshold, or non-negative garrote |
| `nsteps` | int | `6` | 1 to 10 | Number of wavelet decomposition steps (lowered for small pictures as FFmpeg does) |
| `percent` | float | `85.0` | 0.0 to 100.0 | Percent of full denoising of the coefficients below the threshold |
| `planes` | int | `15` | 0 to 15 | Channels to filter, FFmpeg's bits on gbrp: 1 green, 2 blue, 4 red |
| `threshold_type` | enum | `universal` | `universal`, `bayes` | Threshold: the same for the whole picture (VisuShrink), or one per sub-band from its energy (BayesShrink) |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='vaguedenoiser.zip=threshold=4&method=garrote&nsteps=6',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='vaguedenoiser.zip=threshold=4&method=garrote&nsteps=6',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'vaguedenoiser.zip=threshold=4&method=garrote&nsteps=6' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `vaguedenoiser` (`vf_vaguedenoiser.c`), on each R, G, B channel as FFmpeg does on `gbrp`. The channel goes through `nsteps` steps of FFmpeg's 9/7 biorthogonal wavelet (rows, then columns, of the low-low part of the previous step, with FFmpeg's symmetric extensions at the edges), its coefficients are shrunk, and the inverse steps rebuild it. With `threshold_type=universal` every coefficient uses `threshold`; with `bayes` each sub-band gets `threshold^2 / sqrt(mean of squares - threshold)`. Coefficients up to the threshold are multiplied by `1 - percent / 100`; larger ones are kept (`hard`), moved toward 0 by `threshold * percent / 100` (`soft`), or multiplied by `(c^2 - threshold^2 * percent / 100) / c^2` (`garrote`). Alpha is passed through.

The coefficients are 32-bit floats stored in RGBA8 intermediate textures (their 32 bits over the 4 channels, one texture per channel). The manifest has a fixed list of 43 passes (two per step and direction for up to 10 steps, plus 3 for the threshold); the passes of steps above `nsteps` only copy. About 23 ms for a 1920x1080 frame on a laptop RTX 4060, with either threshold type.

Checked against FFmpeg's `format=gbrp,vaguedenoiser` on a noisy test picture (643x361 and 1920x1080: defaults; `threshold=8:method=soft:nsteps=4:percent=100`; `threshold=5:method=hard:type=bayes`; `threshold=6:type=bayes:nsteps=10:planes=5`): identical except some pixels 1 level apart (float sums in another order).

Differences from FFmpeg:

- FFmpeg's option `type` is named `threshold_type` here, because `type` is a WGSL keyword.
- `planes` uses FFmpeg's bits for `gbrp` (1 green, 2 blue, 4 red); bit 8 (alpha) does nothing, alpha is never filtered. YUV video is filtered in RGB, not per Y, U, V plane.
- `nsteps` stops at 10 (FFmpeg allows 32, but caps it from the picture size: 9 for 1920x1080, 10 for 3840x2160).
- On very small pictures, where FFmpeg's edge extension reads past its buffers, the extension here keeps mirroring.
- Values are handled on the 8-bit scale, also for video with more bits (FFmpeg scales `threshold` by the bit depth); the output is not rounded to 8 bits on 16-bit textures.
