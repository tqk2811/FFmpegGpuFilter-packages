# Guided

Smooths the picture while keeping its edges, with the guided filter of FFmpeg's `guided`, self-guided or with a guide picture.

## Inputs

- `src0`: Picture to filter.
- `src1` (optional): Guide picture, of the same size: FFmpeg's `guidance=on`. The input repeats: a node with two input labels (`[0][1]guided.zip`) takes the guide, a node with one label or a chain does not.

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src0`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `guided.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `radius` | int | `3` | 1 to 20 | Radius of the box in pixels: the box is 2 * radius + 1 wide |
| `eps` | float | `0.01` | 0 to 1 | Regularisation: larger values smooth across stronger edges (compared with the variance of 0..1 values) |
| `mode` | enum | `basic` | `basic`, `fast` | fast: compute the model on every `sub`-th pixel, with the radius divided by `sub` |
| `sub` | int | `4` | 2 to 64 | Subsampling ratio of the fast mode |
| `planes` | int | `7` | 0 to 15 | Channels to filter, FFmpeg's bits on gbrp: 1 green, 2 blue, 4 red |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='guided.zip=radius=4&eps=0.005',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='guided.zip=radius=4&eps=0.005',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'guided.zip=radius=4&eps=0.005' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `guided` (`vf_guided.c`), basic and fast modes, with or without a guide. Per R, G, B channel, with `I` the picture and `P` the guide (`I` without one), box means give the coefficients of the local linear model `A = cov(I, P) / (var(I) + eps)` and `B = mean(P) - A * mean(I)`; the output is `mean(A) * I + mean(B)`, `mean` being the box mean of `(2 * radius + 1)^2` samples with the edge samples repeated, as in FFmpeg. In fast mode the model is computed on every `sub`-th pixel of every `sub`-th row with the radius divided by `sub` (1 when `radius < sub`), and each pixel uses the coefficients of the grid point at the top left of its `sub` x `sub` cell, as FFmpeg does. As in FFmpeg the result is cut toward zero to an 8-bit code. Three passes: two compute `A` and `B` (32-bit floats stored over the 4 channels of RGBA8 intermediate textures, one per channel), the third averages them and writes the output. Each pass reads the whole box directly. Alpha is passed through.

Checked against FFmpeg's `format=gbrp,guided=planes=7` on a noisy test picture (642x360): defaults; `radius=8:eps=0.002`; `mode=fast`; `mode=fast:radius=12:sub=3:eps=0.001`; `mode=fast:sub=7:radius=20`; `planes=5:radius=2`; with a blurred, hue-shifted guide `guidance=on:radius=4:eps=0.005` and `guidance=on:mode=fast:radius=8:sub=2`: at most 1 8-bit level apart, except the pixels where FFmpeg wraps around (below).

Differences from FFmpeg:

- With a guide the result can leave 0..255; FFmpeg stores it in a byte without clipping, so 256 becomes 0 and -1 becomes 255. This package clips.
- `planes` uses FFmpeg's bits for `gbrp` (1 green, 2 blue, 4 red) and defaults to 7 (FFmpeg's default 1 filters only the first plane, Y on YUV video); bit 8 (alpha) does nothing. YUV video is filtered in RGB, not per Y, U, V plane.
- Values are handled as 8-bit codes, also for video with more bits.
