# Hald CLUT

Recolours a video through a 3D lookup table (a colour grade) given as a Hald CLUT picture, like FFmpeg's `haldclut` filter.

## Inputs

- `src`: Picture to recolour. Any size; any pixel format that gpufx converts on the GPU.
- `clut`: Hald CLUT picture, a square of level^3 pixels a side (64x64 for level 4, 512x512 for level 8, 1728x1728 for level 12). It holds level^2 entries per channel, red fastest, then green, then blue, row by row, as FFmpeg's `haldclutsrc` writes it.

## Output

Same size as the first input (`src`). Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `haldclut.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `interp` | enum | `tetrahedral` | `nearest`, `trilinear`, `tetrahedral` | Interpolation between the entries of the table |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 -loop 1 -i clut.png -filter_complex \
  "[0][1]gpufx=graph='haldclut.zip=interp=tetrahedral',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 -loop 1 -i clut.png -filter_complex \
  "[0][1]gpufx=graph='haldclut.zip=interp=tetrahedral',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run '[0][1]haldclut.zip=interp=tetrahedral' -i in.png -i clut.png -o out.png
```

## Notes

Port of FFmpeg's `haldclut` (`vf_lut3d.c`). One pass: the colour is scaled to the table, the surrounding entries are read from the CLUT picture with `textureLoad` and mixed by the chosen interpolation; alpha is passed through. The level is found from the width of `clut` (the smallest level whose cube reaches it).

Checked against FFmpeg's `haldclut` with level 4 and level 8 tables: identical with `nearest`, at most 1 8-bit level apart with `trilinear` and `tetrahedral`.

A `.cube` file (FFmpeg's `lut3d`) cannot be loaded by a package; turn it into a Hald CLUT picture once with FFmpeg and feed that to `clut`:

```sh
ffmpeg -f lavfi -i haldclutsrc=8 -vf lut3d=grade.cube -frames:v 1 clut.png
```

In a gpufx graph a still picture is a one-frame input; loop it (`-loop 1 -i clut.png`) so every frame of `src` has a table.

Differences from FFmpeg:

- `interp` offers `nearest`, `trilinear` and `tetrahedral` (FFmpeg also has `pyramid` and `prism`).
- The `clut` option (`first` or `all` frames of the CLUT stream) is not ported: the table is read from whatever frame the second input holds, so a changing CLUT stream is followed frame by frame.
- A `clut` whose width is not a cube is not refused: the next larger level is used.
