# Morpho

Grey-scale morphology with a structuring element given as a picture, like FFmpeg's `morpho` filter: erosion, dilation, opening, closing, gradient, top-hat and black-hat.

## Inputs

- `src`: Picture to filter. Any size; any pixel format that gpufx converts on the GPU.
- `structure`: Structuring element. In each of R, G, B, a pixel above 0 is part of the element for that channel. Its origin is pixel ((w - 1) / 2, (h - 1) / 2), rounded down; only the top-left 63x63 pixels are read.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `morpho.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `mode` | enum | `erode` | `erode`, `dilate`, `open`, `close`, `gradient`, `tophat`, `blackhat` | Morphological transform |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 -loop 1 -i structure.png -filter_complex \
  "[0][1]gpufx=graph='morpho.zip=mode=open',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 -loop 1 -i structure.png -filter_complex \
  "[0][1]gpufx=graph='morpho.zip=mode=open',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run '[0][1]morpho.zip=mode=open' -i in.png -i structure.png -o out.png
```

## Notes

Port of FFmpeg's `morpho` (`vf_morpho.c`). Two passes: the first writes the erosion (minimum over the element) and the dilation (maximum) to two intermediate textures; the second gives the erosion or dilation, the opening (dilation of the erosion), the closing (erosion of the dilation), the gradient (dilation - erosion), the top-hat (picture - opening) or the black-hat (closing - picture). Pixels of the element that fall outside the picture are left out, as in FFmpeg. Each pass reads the element directly, so the cost grows with its area. Alpha is passed through.

Checked against FFmpeg's `morpho=planes=7` on `gbrap` for every mode, with an odd 5x3 asymmetric element and an even 8x6 one: identical.

Differences from FFmpeg:

- `planes` is not ported: R, G and B are all filtered, each with its own channel of `structure`.
- `structure=first` is not ported: the element is read from whatever frame the second input holds.
- The element is limited to 63x63 pixels (FFmpeg uses the whole picture, with a faster algorithm for large elements).
