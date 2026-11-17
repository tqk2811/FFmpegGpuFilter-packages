# Transpose

Rotates the picture by 90 degrees, optionally flipped, like FFmpeg's `transpose` filter.

## Inputs

- `src`

Any size; any pixel format that gpufx converts on the GPU.

## Output

The input's size with width and height swapped, or the input's size when `passthrough` leaves the picture as it is. The size is computed once, when the filter is configured, so `dir` may change while the stream runs but `passthrough` may not. Pixel format: the input's, when the effect may output it (the manifest has no `output` rule).

## Options

Written inline after the package name: `transpose.zip=name=value`. Several options are separated by `&` in an FFmpeg `graph='...'` string (`:` also works but must be written `\:` there) or by `:` in `gpufx run`. A value is a literal or an FFmpeg expression in `t`, `n`, `w`, `h`, `a`, `sar`, `dar`; commas inside an FFmpeg command line are escaped as `\,`. See the repo [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md) and [EFFECT_FORMAT](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/docs/EFFECT_FORMAT.md).

| Name | Type | Default | Range | Description |
|------|------|---------|-------|-------------|
| `dir` | enum | `cclock_flip` | `cclock_flip`, `clock`, `cclock`, `clock_flip` | cclock_flip = 90 degrees counter-clockwise and flipped vertically, clock = 90 degrees clockwise, cclock = 90 degrees counter-clockwise, clock_flip = 90 degrees clockwise and flipped vertically |
| `passthrough` | enum | `none` | `none`, `portrait`, `landscape` | Leave the picture as it is when it is already portrait (height >= width) or landscape (width >= height) |

## Example

```sh
ffmpeg -init_hw_device vulkan=vk:0,disable_multiplane=1 -filter_hw_device vk -i in.mp4 \
  -vf "format=nv12,gpufx=graph='transpose.zip=dir=clock',hwdownload,format=nv12" out.mp4
```

Direct3D 12 (Windows):

```sh
ffmpeg -init_hw_device d3d12va=dx -filter_hw_device dx -i in.mp4 \
  -vf "format=nv12,gpufx=graph='transpose.zip=dir=clock',hwdownload,format=nv12" out.mp4
```

The effect runs on every backend the filter supports (Vulkan, D3D12/D3D11, Metal on macOS); see the [README](https://github.com/tqk2811/FFmpegGpuFilter/blob/master/README.md).

With the `gpufx` CLI on a PNG:

```sh
gpufx run 'transpose.zip=dir=clock' -i in.png -o out.png
```

## Notes

Port of FFmpeg's `transpose` (`vf_transpose.c`). One pass of `textureLoad`: output pixel (x, y) reads input pixel (y, x), mirrored on the axes `dir` asks for. Flipping without rotating (`hflip`, `vflip`) is the `mirror` package.

Checked against FFmpeg's `transpose` for every `dir` and `passthrough`: identical.

Differences from FFmpeg: `dir` takes the names (or their numbers 0 to 3); FFmpeg's deprecated numbers 4 to 7 (passthrough folded into `dir`) are not accepted, use `passthrough`.
