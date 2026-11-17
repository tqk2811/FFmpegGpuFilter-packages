# Remap

Moves pixels by two coordinate maps, like FFmpeg's `remap`.

## Inputs

- `src`: Picture to remap.
- `xmap`: For each output pixel, the X coordinate of the source pixel, in its first channel.
- `ymap`: The Y coordinate, the same way; same size as `xmap`.

Any sizes. FFmpeg's maps are 16-bit gray (`gray16`), which gpufx does not take as an input format: convert them to `rgba64le` (`format=rgba64le`) before the filter, which keeps them exact up to coordinate 2047. 8-bit maps (`gray`) work with `map_max=255`, for coordinates up to 255.

## Output

The size of `xmap`. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `remap.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `fill` | color | `#000000` |  | Color of the output pixels whose coordinates fall outside the source |
| `map_max` | float | `65535` | 1 to 65535 | Map code of a full-scale value: 65535 for 16-bit maps, 255 for 8-bit maps |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 -loop 1 -i xmap.png -loop 1 -i ymap.png -filter_complex \
  "[1]format=rgba64le[x];[2]format=rgba64le[y];[0][x][y]gpufx=graph='remap.zip=fill=#ff0000',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 -loop 1 -i xmap.png -loop 1 -i ymap.png -filter_complex \
  "[1]format=rgba64le[x];[2]format=rgba64le[y];[0][x][y]gpufx=graph='remap.zip=fill=#ff0000',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run '[0][1][2]remap.zip=fill=#ff0000:map_max=255' -i in.png -i xmap8.png -i ymap8.png -o out.png
```

## Notes

Port of FFmpeg's `remap` (`vf_remap.c`), nearest pixel as in FFmpeg. A map value is `round(value * map_max)`; a pixel whose X or Y is past the source's width or height takes `fill`. Alpha comes from the source pixel, or from `fill`.

Checked against FFmpeg's `remap=fill=red` with 16-bit maps of a warp (about a quarter of the pixels outside the source), the effect reading the same coordinates from 8-bit maps with `map_max=255`: identical.

Differences from FFmpeg:

- `format=gray` (a gray output) is not ported; the output is always color.
- Through the 16-bit float textures used for more than 8 bits, coordinates above 2047 lose precision.
