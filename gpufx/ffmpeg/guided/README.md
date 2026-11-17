# Guided

Smooths the picture while keeping its edges, with the self-guided filter of FFmpeg's `guided` (guidance off).

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `guided.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `radius` | int | `3` | 1 to 20 | Radius of the box in pixels: the box is 2 * radius + 1 wide |
| `eps` | float | `0.01` | 0 to 1 | Regularisation: larger values smooth across stronger edges (compared with the variance of 0..1 values) |

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

Port of FFmpeg's `guided` (`vf_guided.c`) in basic mode without a guidance input. Two passes: the first computes, per pixel and per R, G, B channel, the box mean and variance of the picture and the coefficients `a = var / (var + eps)`, `b = mean - a * mean` (two intermediate textures); the second averages `a` and `b` over the same box and writes `mean(a) * I + mean(b)`. Boxes are cut at the picture's edges and divided by the pixels they hold. Each pass reads the whole box directly, (2 * radius + 1)^2 texels per pixel. Alpha is passed through.

Checked against FFmpeg's `guided=planes=7` on `gbrap` (noisy test picture, radius 1, 3 and 8): at most 2 8-bit levels apart inside the picture, up to 8 levels in the outer `radius` pixels, where FFmpeg's box handles the edge differently.

Differences from FFmpeg:

- `guidance=on` (a second input as the guide), `mode=fast` and `sub` are not ported.
- `planes` is not ported: R, G and B are all filtered (FFmpeg filters only the first plane by default).
- The coefficients go through the intermediate textures, which hold 8 bits for 8-bit video.
