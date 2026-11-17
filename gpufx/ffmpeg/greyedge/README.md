# Grey Edge

Automatic white balance like FFmpeg's `greyedge`: it estimates the light color from the Gaussian derivatives of the picture and divides it out.

## Inputs

- `src`: Picture to correct.

At least 3 pixels wide; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `greyedge.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `difford` | int | `1` | 0 to 2 | Order of the Gaussian derivative: 0 uses the smoothed picture (grey world, or max-RGB with minknorm 0), 1 the gradient, 2 the second derivatives |
| `minknorm` | int | `1` | 0 to 20 | Minkowski norm of the estimate: 0 takes the maximum (max-RGB), 1 the mean, higher values lean towards the maximum |
| `sigma` | float | `1.0` | 0.0 to 10.0 | Standard deviation of the Gaussian, in pixels; must be at least 1/6 when difford is above 0, else the picture is left as it is |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='greyedge.zip=difford=1&minknorm=5&sigma=2',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='greyedge.zip=difford=1&minknorm=5&sigma=2',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'greyedge.zip=difford=1&minknorm=5&sigma=2' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `greyedge` (`vf_colorconstancy.c`, the only filter of that file; FFmpeg has no filter called `colorconstancy`). For each R, G, B channel the picture (8-bit codes) is filtered with Gaussian derivative kernels of order `difford` and size `2 * round(3 * sigma) + 1`; the magnitude is set to 0 where the channel is 255, and its maximum (`minknorm=0`) or Minkowski norm over the frame is the light estimate. The estimate is scaled to unit length and every value becomes `round(v / (light * sqrt(3)))`. Alpha is passed through. `difford=0` with `minknorm=1` is the grey world method, with `minknorm=0` max-RGB.

Four passes: the derivative magnitudes per pixel (the separable kernels are applied as a 2-D loop, `size^2` texels per pixel, so 49 at the default sigma and 3721 at sigma 10), one reduction per row and channel, one over the rows, then the correction. Values travel between passes as the 32 bits of an `f32` over the four 8-bit channels of a texel. Kept from FFmpeg for parity: its kernels are centred at `size >> 2` instead of `size >> 1`, so they are off centre.

Checked against FFmpeg's `greyedge` on the test picture and a low-contrast copy (defaults; `difford=2:minknorm=5:sigma=2`; `difford=0:minknorm=0:sigma=0`; `difford=1:minknorm=0:sigma=3`; `difford=0:minknorm=2:sigma=1.5`): identical except for one pixel 1 level apart.

Differences from FFmpeg:

- `sigma` stops at 10 (FFmpeg allows 1024), which keeps the per-pixel kernel loop bounded.
- FFmpeg refuses `difford` above 0 with `sigma` under 1/6; the effect leaves the picture as it is.
- Values are handled as 8-bit codes, also for video with more bits.
