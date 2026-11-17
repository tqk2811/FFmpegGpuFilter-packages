# NL-Means

Non-local means denoiser on a single frame, like FFmpeg's `nlmeans`.

## Inputs

- `src`: Picture to denoise.

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `nlmeans.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `s` | float | `1.0` | 1.0 to 30.0 | Denoising strength |
| `p` | int | `7` | 1 to 21 | Patch size, odd (an even value is raised by one) |
| `r` | int | `15` | 1 to 31 | Research window size, odd (an even value is raised by one) |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='nlmeans.zip=s=4&p=7&r=15',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='nlmeans.zip=s=4&p=7&r=15',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'nlmeans.zip=s=4&p=7&r=15' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `nlmeans` (`vf_nlmeans.c`), on each R, G, B channel as FFmpeg does on `gbrp`. For every pixel of the `r` x `r` research window (inside the picture) the sum of squared 8-bit differences between its `p` x `p` patch and the pixel's own patch gives the weight `exp(-ssd / (10 s)^2)`, 0 from FFmpeg's cut-off `log(255) * (10 s)^2` on; the pixel itself weighs 1. Patch pixels outside the picture take the nearest edge pixel. Alpha is passed through. One pass. A workgroup loads its 8x8 tile with the patch and research margins into workgroup memory, and for each offset of the research window sums the squared differences along the patch rows once per tile row; each pixel then adds up the `p` row sums of its patch. The sums are integers, so the weights are those of the direct sum. About 0.11 s for a 1920x1080 frame with the defaults on a laptop RTX 4060 (16 ms with `p=3:r=7`, 1.4 s with `p=21:r=31`), still far from real time.

Checked against FFmpeg's `format=gbrp,nlmeans` on a noisy test picture (643x361 and 1920x1080; defaults; `s=4:p=5:r=9`; `s=10:p=3:r=21`; `s=6:p=21:r=31`; `s=3:p=6:r=4`): identical except a few pixels 1 level apart.

Differences from FFmpeg:

- `pc` and `rc` (patch and window of the chroma planes) are not ported: the three RGB channels use `p` and `r`, as FFmpeg does on `gbrp` when they are left at 0. YUV video is filtered in RGB, not per Y, U, V plane.
- `p` stops at 21 and `r` at 31 (FFmpeg allows 99).
- Values are handled as 8-bit codes, also for video with more bits.
