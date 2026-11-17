# Histogram Equalization

Global histogram equalization of each frame's luma, like FFmpeg's `histeq`.

## Inputs

- `src`: Picture to equalize.

At least 256 pixels wide; any pixel format that gpufx converts on the GPU.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `histeq.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `strength` | float | `0.2` | 0.0 to 1.0 | Mix of the equalized and the original luma: 0 leaves the picture, 1 equalizes fully |
| `intensity` | float | `0.21` | 0.0 to 1.0 | Largest output luma of the equalization, as a fraction of 1000/255 (0.255 maps to full white) |
| `antibanding` | enum | `none` | `none`, `weak`, `strong` | Random dither of the output luma between neighbouring table entries, against banding |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='histeq.zip=strength=0.2&intensity=0.21',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='histeq.zip=strength=0.2&intensity=0.21',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'histeq.zip=strength=0.2&intensity=0.21' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `histeq` (`vf_histeq.c`), with its integer math on 8-bit codes. The luma `(55 r + 182 g + 19 b) >> 8` of every pixel is counted in a 256-bin histogram; its running sum, scaled by `intensity` and mixed with the identity by `strength`, is the lookup table, and each pixel's R, G, B are scaled by `lut[luma] / luma` (by `255 / max(r, g, b)` when that would overflow). Black pixels stay black.

The histogram takes three passes: the first counts, for each row and bin, the pixels of that luma (one thread per row and bin, so it reads every row 256 times), the second adds up the cumulative counts per bin, the last maps the pixels. The counts travel between passes as 32-bit integers in the four 8-bit channels of a texel, hence the 256-pixel minimum width.

Checked against FFmpeg's `histeq` on the test picture and a low-contrast copy (defaults, `strength=0.25`, `strength=1` with `intensity=0.255`): identical without antibanding. With antibanding the dither differs pixel by pixel but the channel means match within 0.1 level.

Differences from FFmpeg:

- FFmpeg writes the luma into the alpha channel of RGBA output; alpha is passed through here.
- `antibanding` draws its random offset from a hash of the pixel position instead of FFmpeg's sequential random generator, which runs pixel after pixel; the result is the same kind of dither but not the same pixels.
- Like FFmpeg, `strength` above 0.255 makes the table go negative and the colors wrap around; this is kept for parity.
- Pictures over about 4 million pixels (above 1080p) compute the table entries in float when the 32-bit product would overflow, where FFmpeg overflows.
